// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataC
import SPFKUtils

/// A Swift file format agnostic wrapper to TagLib metadata properties I/O
public struct TagProperties: Hashable, Codable, Sendable {
    /// Use the various access methods in TagPropertiesContainerModel for mutation
    public var data = TagData()

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

    /// Create a dictionary from an audio file url
    /// - Parameter url: the `URL` to parse for metadata
    public init(url: URL) throws {
        try load(url: url)
    }

    public mutating func load(url: URL) throws {
        let tagFile = TagFile(path: url.path)
        tagFile.load()

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

    /// Write the current tags dictionary back to the file
    public func save(to url: URL) throws {
        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = tagLibPropertyMap

        guard tagFile.save() else {
            throw NSError(description: "Failed to update tags in \(url.path)")
        }
    }

    public mutating func removeAllAndSave(to url: URL) throws {
        removeAll()
        try Self.removeAllTags(in: url)
    }

    public mutating func merge(data otherData: TagData, scheme: DictionaryMergeScheme = .replace) {
        data = [data, otherData].merge(scheme: scheme)
    }
    
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
    /// Read in tags and copy to the destination
    /// - Parameters:
    ///   - source: The file to read from
    ///   - destination: The file to write to
    public static func copyTags(from source: URL, to destination: URL) throws {
        TagLibBridge.copyTags(fromPath: source.path, toPath: destination.path)
    }

    public static func removeAllTags(in url: URL) throws {
        guard TagLibBridge.removeAllTags(url.path) else {
            throw NSError(description: "Failed to removeAll tags in \(url.path)")
        }
    }
}
