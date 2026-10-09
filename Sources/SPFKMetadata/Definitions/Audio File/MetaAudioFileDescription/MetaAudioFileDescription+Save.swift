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
    /// A part that was not read (``readStatus``), failed to write, or that the container cannot
    /// store is left as the file has it; ``MetadataError/incompleteSave(written:failures:)`` then
    /// names each, after everything else is written. Any other error means nothing was written.
    public mutating func save(
        dirtyFlags: Set<MetadataDirtyFlag> = [.metadata],
        storedXMPPacket: StoredXMPPacketWrite = .keep
    ) throws {
        // First, so a locked file fails with one error rather than a partial save; TagLib
        // reports the lock only as `false`.
        try url.requireWritable()

        if storedXMPPacket != .keep, !(fileType.map(StoredXMPPacketWrite.fileTypes.contains) ?? false) {
            throw NSError(description: "A .\(url.pathExtension) file stores no XMP packet of its own")
        }

        let unstorable = unstorableFlags(in: dirtyFlags)
        let unread = unreadFlags(in: dirtyFlags.subtracting(unstorable))
        let writable = dirtyFlags.subtracting(unstorable).subtracting(unread)
        let unreadFailures = unreadErrors(for: unread)
        let unstorableFailures: [MetadataError] = unstorable.isEmpty ? [] : [.unstorable(fileType, unstorable)]

        // Nothing else to write, so the file is left untouched, modification date included.
        if writable.isEmpty, unreadFailures.isNotEmpty || unstorableFailures.isNotEmpty {
            throw MetadataError.incompleteSave(written: [], failures: unreadFailures + unstorableFailures)
        }

        let failed = try writeContainer(writable, storedXMPPacket: storedXMPPacket)

        #if os(macOS)
            let finderTags = urlProperties.finderTags
            try url.set(finderTags: finderTags)
            try url.updateModificationDate()

            // Rebuilt, or a stale date reads as an external change on the next scan.
            urlProperties = URLProperties(url: url)
        #endif

        let writeFailures = MetadataComponent.allCases.filter(failed.contains).map { MetadataError.writeFailed($0, url) }
        let failures = unreadFailures + writeFailures + unstorableFailures

        guard failures.isNotEmpty else { return }

        var written = writable.subtracting(failed.map(\.dirtyFlag))

        // Left to the caller's XMP write.
        if storedXMPPacket == .keep {
            written.remove(.xmp)
        }

        throw MetadataError.incompleteSave(written: written, failures: failures)
    }

    /// The container's part of a save: the components that failed. Throws when nothing was written.
    private mutating func writeContainer(
        _ writable: Set<MetadataDirtyFlag>, storedXMPPacket: StoredXMPPacketWrite
    ) throws -> Set<MetadataComponent> {
        let metadataNeedsSave = writable.contains(.metadata)
        let imageNeedsSave = writable.contains(.image)
        let markersNeedsSave = writable.contains(.markers)

        // A container save can rewrite the whole file; a Finder tag change shouldn't pay it.
        guard metadataNeedsSave || imageNeedsSave || markersNeedsSave else {
            do {
                try storedXMPPacket.write(to: url)
                return []
            } catch {
                return [.xmp]
            }
        }

        if fileType == .wav {
            return try saveWave(
                metadataNeedsSave: metadataNeedsSave, imageNeedsSave: imageNeedsSave,
                markersNeedsSave: markersNeedsSave, storedXMPPacket: storedXMPPacket
            )
        }

        return try saveSession(
            metadataNeedsSave: metadataNeedsSave, imageNeedsSave: imageNeedsSave,
            markersNeedsSave: markersNeedsSave, storedXMPPacket: storedXMPPacket
        )
    }
}
