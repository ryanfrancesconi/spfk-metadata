// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
internal import SPFKMetadataC
import SPFKUtils

extension TagProperties {
    /// Throws `MetadataError.readFailed` when the file can't be opened or TagLib doesn't parse the format.
    public init(url: URL) throws {
        self.init()
        try load(url: url)
    }

    /// Adds the file's tags over what is already held; nothing is cleared first. A WAV's are read
    /// as its parse reads them: INFO, then ID3 over it.
    public mutating func load(url: URL) throws {
        if AudioFileType(url: url) == .wav {
            let waveFile = WaveFileC(path: url.path)
            guard waveFile.loadTags() else { throw MetadataError.readFailed(.tags, url) }

            if let value = waveFile.audioPropertiesC {
                audioProperties = AudioFormatProperties(cObject: value)
            }

            load(waveFile: waveFile)
            return
        }

        let tagFile = TagFile(path: url.path)

        guard tagFile.load() else {
            throw MetadataError.readFailed(.tags, url)
        }

        if let value = tagFile.audioProperties {
            audioProperties = AudioFormatProperties(cObject: value)
        }

        guard let dict = tagFile.dictionary as? [String: String] else {
            throw MetadataError.readFailed(.tags, url)
        }

        for item in dict {
            data.set(taglibKey: item.key, value: item.value)
        }
    }

    /// The tag changes this instance carries relative to the file on disk, sorted by field name.
    ///
    /// Reads the file rather than trusting a recorded copy: an element marked dirty holds the
    /// values it had when edited, and only the file can say what they are being compared against.
    public func difference(fromFileAt url: URL) throws -> [TagValueChange] {
        try difference(from: TagProperties(url: url))
    }

    /// Replaces every tag in the file. Artwork and chapters are kept, and so is every other ID3v2 frame
    /// of an MP3 or WAV with no property key; the stored XMP packet changes only as
    /// `storedXMPPacket` says. A WAV's tags are written only when they differ from the file's, its
    /// INFO as the mirror of its ID3 tag; one that writes them but not its rating throws
    /// ``MetadataError/incompleteSave(written:failures:)``.
    public func save(to url: URL, storedXMPPacket: StoredXMPPacketWrite = .keep) throws {
        if AudioFileType(url: url) == .wav {
            let waveFile = WaveFileC(path: url.path)
            waveFile.setTagChanges(self)
            storedXMPPacket.apply { waveFile.xmpNeedsSave = true; waveFile.xmpPacket = $0 }
            waveFile.bextNeedsSave = false
            waveFile.iXMLNeedsSave = false
            waveFile.markersNeedsSave = false
            waveFile.artworkNeedsSave = false

            guard waveFile.save() else {
                let failed = waveFile.failedComponents
                guard !failed.contains(.container) else { throw MetadataError.writeFailed(.tags, url) }

                let attempted: Set<MetadataComponent> = storedXMPPacket == .keep ? [.tags, .rating] : [.tags, .rating, .xmp]
                throw failed.incompleteSave(attempted: attempted, url: url)
            }
            return
        }

        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = tagLibPropertyMap
        storedXMPPacket.apply { tagFile.xmpNeedsSave = true; tagFile.xmpPacket = $0 }

        guard tagFile.save() else {
            throw MetadataError.writeFailed(.tags, url)
        }
    }

    /// Clears all in-memory tags and strips all tags from the file on disk.
    public mutating func removeAllAndSave(to url: URL) throws {
        removeAll()
        try Self.removeAllTags(in: url)
    }

    /// Replaces the destination's tags with the source's, rating included. Chapters are markers and
    /// are not copied.
    public static func copyTags(from source: URL, to destination: URL) throws {
        guard TagLibBridge.copyTags(fromPath: source.path, toPath: destination.path) else {
            throw MetadataError.copyFailed(.tags, from: source, to: destination)
        }
    }

    public static func removeAllTags(in url: URL) throws {
        guard TagLibBridge.removeAllTags(url.path) else {
            throw MetadataError.removeFailed(.tags, url)
        }
    }
}
