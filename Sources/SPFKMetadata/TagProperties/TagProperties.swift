// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataC
import SPFKUtils

/// Format-agnostic tag I/O powered by TagLib.
///
/// Reads and writes ID3v2, RIFF INFO, Vorbis Comment, and other tag formats through a unified
/// ``TagData`` container. Supports MP3, WAV, AIFF, FLAC, OGG, M4A, and other TagLib-supported formats.
/// Use ``init(url:)`` to read tags and ``save(to:)`` to write them back.
public struct TagProperties: Hashable, Codable, Sendable {
    /// The underlying tag storage. Use ``TagPropertiesContainerModel`` accessors for mutation.
    public var data = TagData()

    /// Audio format properties (sample rate, channels, etc.) read alongside the tags by TagLib.
    public var audioProperties: AudioFormatProperties?

    private var tagLibPropertyMap: [String: String] {
        var dict: [String: String] = .init()

        // ID3 and INFO
        for item in data.tags {
            dict[item.key.taglibKey] = item.value
        }

        // Custom ID3, TXXX
        for item in data.customTags {
            dict[item.key.uppercased()] = item.value
        }

        return dict
    }

    public init() {}

    /// Reads all tags from the audio file at the given URL via TagLib.
    /// - Parameter url: URL to the audio file.
    /// - Throws: If the file cannot be opened or TagLib doesn't support the format.
    public init(url: URL) throws {
        try load(url: url)
    }

    /// Loads tags from the given URL, replacing any existing tag data.
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

    /// Writes all current tags back to the file via TagLib.
    /// - Parameter url: URL of the file to update.
    public func save(to url: URL) throws {
        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = tagLibPropertyMap

        guard tagFile.save() else {
            throw NSError(description: "Failed to update tags in \(url.path)")
        }
    }

    /// Clears all in-memory tags and strips all tags from the file on disk.
    public mutating func removeAllAndSave(to url: URL) throws {
        removeAll()
        try Self.removeAllTags(in: url)
    }

    /// Merges another `TagData` into this instance using the specified scheme.
    public mutating func merge(data otherData: TagData, scheme: DictionaryMergeScheme = .replace) {
        data = [data, otherData].merge(scheme: scheme)
    }
    
    /// Removes all keys found in `otherData` from this instance.
    public mutating func remove(data otherData: TagData) {
        data.remove(data: otherData)
    }
}

extension TagProperties: TagPropertiesContainerModel {
    public var tags: TagKeyDictionary {
        get { data.tags }
        set { data.tags = newValue }
    }

    public var customTags: [String: String] {
        get { data.customTags }
        set { data.customTags = newValue }
    }
}

extension TagProperties {
    /// Copies all tags from one file to another via TagLib, overwriting existing tags in the destination.
    /// - Parameters:
    ///   - source: The file to read tags from.
    ///   - destination: The file to write tags to.
    public static func copyTags(from source: URL, to destination: URL) throws {
        guard TagLibBridge.copyTags(fromPath: source.path, toPath: destination.path) else {
            throw NSError(description: "Failed to copy tags from \(source.path) to \(destination.path)")
        }
    }

    /// Strips all tags from the file on disk via TagLib.
    public static func removeAllTags(in url: URL) throws {
        guard TagLibBridge.removeAllTags(url.path) else {
            throw NSError(description: "Failed to removeAll tags in \(url.path)")
        }
    }
}
