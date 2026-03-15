// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataC
import SPFKUtils

extension TagProperties {
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
