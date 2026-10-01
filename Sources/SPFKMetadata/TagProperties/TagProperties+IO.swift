// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
import SPFKMetadataC
import SPFKUtils

extension TagProperties {
    /// Throws when the file can't be opened or TagLib doesn't parse the format.
    public init(url: URL) throws {
        self.init()
        try load(url: url)
    }

    /// Adds the file's tags over what is already held; nothing is cleared first.
    public mutating func load(url: URL) throws {
        let tagFile = TagFile(path: url.path)

        guard tagFile.load() else {
            throw NSError(description: "Failed to load tag file: \(url.path)")
        }

        if let value = tagFile.audioProperties {
            audioProperties = AudioFormatProperties(cObject: value)
        }

        guard let dict = tagFile.dictionary as? [String: String] else {
            throw NSError(description: "Failed to open file or no metadata for: \(url.path)")
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

    /// Replaces every tag in the file. Artwork is kept, and so is every ID3v2 frame of an MP3 that has
    /// no property key (chapters included); its stored XMP packet changes only as `storedXMPPacket` says.
    public func save(to url: URL, storedXMPPacket: StoredXMPPacketWrite = .keep) throws {
        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = tagLibPropertyMap
        storedXMPPacket.apply { tagFile.xmpNeedsSave = true; tagFile.xmpPacket = $0 }

        guard tagFile.save() else {
            throw NSError(description: "Failed to update tags in \(url.path)")
        }
    }

    /// Clears all in-memory tags and strips all tags from the file on disk.
    public mutating func removeAllAndSave(to url: URL) throws {
        removeAll()
        try Self.removeAllTags(in: url)
    }

    /// Replaces the destination's tags with the source's, rating included.
    public static func copyTags(from source: URL, to destination: URL) throws {
        guard TagLibBridge.copyTags(fromPath: source.path, toPath: destination.path) else {
            throw NSError(description: "Failed to copy tags from \(source.path) to \(destination.path)")
        }
    }

    public static func removeAllTags(in url: URL) throws {
        guard TagLibBridge.removeAllTags(url.path) else {
            throw NSError(description: "Failed to removeAll tags in \(url.path)")
        }
    }
}
