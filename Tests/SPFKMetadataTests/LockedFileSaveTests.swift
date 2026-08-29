// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#if os(macOS)

    import Foundation
    import SPFKFileSystem
    import SPFKMetadataBase
    import SPFKTesting
    import Testing

    @testable import SPFKMetadata

    /// The regression test for the originally reported symptom: a file that read fine and whose tag
    /// save returned "Failed to update tags in <path>", naming neither the lock nor the fact that
    /// nothing had been attempted.
    ///
    /// TagLib is where it surfaced and not what was wrong. `FileStream` opens `"rb+"` first and falls
    /// back to `"rb"` when that returns `EPERM`, so the file parses and only `save()` refuses — and it
    /// refuses by returning `false`, with the `debug()` beside the fallback compiled out under
    /// `NDEBUG`. The guard at the entry point is what makes that path unreachable.
    @Suite(.tags(.file))
    struct LockedFileSaveTests {
        @Test func aLockedFileReportsTheLockRatherThanAGenericFailure() throws {
            let url = try Self.temporaryCopyOfFixture()
            defer { Self.discard(url) }

            var description = MetaAudioFileDescription(url: url, fileType: .wav)
            try url.lock()

            let error = #expect(throws: FileLockError.self) {
                try description.save(dirtyFlags: [.metadata])
            }

            #expect(error?.state == .locked)
            #expect(error?.canUnlock == true)
        }

        /// The guard is at the top, so nothing is half-written. The modification-date bump is the last
        /// thing a save does and the tag write is the first, so an untouched date covers both.
        @Test func aRefusedSaveWritesNothing() throws {
            let url = try Self.temporaryCopyOfFixture()
            defer { Self.discard(url) }

            var description = MetaAudioFileDescription(url: url, fileType: .wav)
            let before = try Self.modificationDate(of: url)

            try url.lock()

            #expect(throws: FileLockError.self) {
                try description.save(dirtyFlags: [.metadata])
            }

            try url.unlock()

            #expect(try Self.modificationDate(of: url) == before)
        }

        @Test func anUnlockedFileSavesNormally() throws {
            let url = try Self.temporaryCopyOfFixture()
            defer { Self.discard(url) }

            var description = MetaAudioFileDescription(url: url, fileType: .wav)

            try url.lock()
            #expect(throws: FileLockError.self) { try description.save(dirtyFlags: [.metadata]) }

            try url.unlock()

            #expect(throws: Never.self) { try description.save(dirtyFlags: [.metadata]) }
        }

        // MARK: - Harness

        private static func temporaryCopyOfFixture() throws -> URL {
            let source = TestBundleResources.shared.wav_bext_v2
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("locked-save-\(UUID().uuidString).wav")

            try FileManager.default.copyItem(at: source, to: destination)

            return destination
        }

        /// The flag has to come off first — a locked file cannot be deleted, and one left behind in
        /// the temporary directory stays undeletable.
        private static func discard(_ url: URL) {
            try? url.unlock()
            try? FileManager.default.removeItem(at: url)
        }

        private static func modificationDate(of url: URL) throws -> Date? {
            try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }
    }

#endif
