// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKFileSystem
import SPFKMetadataBase
import SPFKUtils

extension MetaAudioFileDescription {
    /// Writes what `dirtyFlags` names, then the Finder tags and modification date. `.xmp` is
    /// written elsewhere; `storedXMPPacket` replaces or removes the packet a WAV or MP3 stores,
    /// in the same TagLib save.
    ///
    /// Each component of a flag is refused on its own: one that was not read (``readStatus``),
    /// failed to write, or that the container cannot store is left as the file has it, and
    /// ``MetadataError/incompleteSave(written:failures:)`` then names each, after everything else
    /// is written. Any other error means nothing was written.
    public mutating func save(
        dirtyFlags: Set<MetadataDirtyFlag> = [.tags],
        storedXMPPacket: StoredXMPPacketWrite = .keep
    ) throws {
        // First, so a locked file fails with one error rather than a partial save; TagLib
        // reports the lock only as `false`.
        try url.requireWritable()

        if storedXMPPacket != .keep, !(fileType.map(StoredXMPPacketWrite.fileTypes.contains) ?? false) {
            throw MetadataError.unsupportedFormat(fileType?.utType, .xmp)
        }

        let unstorable = unstorableFlags(in: dirtyFlags)
        let requested = Set(dirtyFlags.subtracting(unstorable).flatMap(\.components))
        let unread = MetadataComponent.allCases.filter { requested.contains($0) && !readStatus.holdsFileValue(of: $0) }
        var writable = requested.subtracting(unread)

        // The rating is part of the tag map, so it is written only with the tags.
        if !writable.contains(.tags) { writable.remove(.rating) }

        // Left to the caller's XMP write.
        if storedXMPPacket == .keep { writable.remove(.xmp) }

        let unreadFailures = unread.map { MetadataError.readFailed($0, url) }
        let unstorableFailures: [MetadataError] = unstorable.isEmpty ? [] : [.unstorable(fileType?.utType, unstorable)]

        // Nothing else to write, so the file is left untouched, modification date included.
        if writable.isDisjoint(with: componentsInFile), unreadFailures.isNotEmpty || unstorableFailures.isNotEmpty {
            throw MetadataError.incompleteSave(written: [], failures: unreadFailures + unstorableFailures)
        }

        var failed = try writeContainer(writable, storedXMPPacket: storedXMPPacket)

        #if os(macOS)
            do {
                try urlProperties.finishSave(at: url)
            } catch {
                Log.error("Failed to write the Finder tags of \(url.lastPathComponent):", error)
                failed.insert(.finderTags)
            }
        #endif

        let writeFailures = MetadataComponent.allCases.filter(failed.contains).map { MetadataError.writeFailed($0, url) }
        let failures = unreadFailures + writeFailures + unstorableFailures

        guard failures.isNotEmpty else { return }

        throw MetadataError.incompleteSave(written: writable.subtracting(failed), failures: failures)
    }

    /// The components a save can find in this file. BEXT and iXML are a WAV's or FLAC's own
    /// chunks; elsewhere a save of their flag has none to write, and leaves none behind.
    private var componentsInFile: Set<MetadataComponent> {
        let all = Set(MetadataComponent.allCases)
        return fileType == .wav || fileType == .flac ? all : all.subtracting([.bext, .ixml])
    }

    /// The container's part of a save: the components that failed. Throws when nothing was written.
    private mutating func writeContainer(
        _ writable: Set<MetadataComponent>, storedXMPPacket: StoredXMPPacketWrite
    ) throws -> Set<MetadataComponent> {
        // A container save can rewrite the whole file; a Finder tag change shouldn't pay it.
        guard !writable.isDisjoint(with: [.tags, .bext, .ixml, .artwork, .markers]) else {
            do {
                try storedXMPPacket.write(to: url)
                return []
            } catch {
                return [.xmp]
            }
        }

        if fileType == .wav {
            return try saveWave(writable, storedXMPPacket: storedXMPPacket)
        }

        return try saveSession(writable, storedXMPPacket: storedXMPPacket)
    }
}
