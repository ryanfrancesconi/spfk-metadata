// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKTesting
import SPFKVideo
import Testing

@testable import SPFKMetadata

/// The third branch of `init(parsing:)`: a container neither `AVAudioFile` nor any tag store can
/// open, which `AVAsset` can still play. Format and length come from the asset read alone.
@Suite("MetaAudioFileDescription MXF")
struct MetaAudioFileDescriptionMXFTests {
    @Test("Parses format and length from the asset", .enabled(if: ProVideoFormats.isAvailable))
    func parsesFromAsset() async throws {
        let url = TestBundleResources.shared.sample_mxf
        let description = try await MetaAudioFileDescription(parsing: url)

        #expect(description.fileType == .mxf)

        let format = try #require(description.audioFormat)
        #expect(format.sampleRate > 0)
        #expect(format.channelCount > 0)
        #expect(format.duration > 0)

        // The frame count comes from the same asset read, and is what this flag is derived from.
        #expect(description.isAVPlayable)
    }

    /// No tag store can open MXF, so a save has to fail loudly. A silent success here would clear
    /// the dirty flag and lose the edit with nothing reported anywhere.
    @Test("Saving tags to it throws", .enabled(if: ProVideoFormats.isAvailable))
    func savingTagsThrows() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spfk-mxf-\(UUID().uuidString)")
            .appendingPathExtension("mxf")

        try FileManager.default.copyItem(at: TestBundleResources.shared.sample_mxf, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var description = try await MetaAudioFileDescription(parsing: url)

        #expect(throws: (any Error).self) {
            try description.save(dirtyFlags: [.metadata])
        }
    }

    /// The guard that keeps a genuinely unreadable file an import error rather than an empty row.
    /// Nothing in the chain can open this, so the asset read's failure has to propagate.
    @Test("A corrupt file still throws")
    func corruptFileThrows() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spfk-corrupt-\(UUID().uuidString)")
            .appendingPathExtension("mxf")

        try Data(repeating: 0, count: 4096).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: (any Error).self) {
            _ = try await MetaAudioFileDescription(parsing: url)
        }
    }
}
