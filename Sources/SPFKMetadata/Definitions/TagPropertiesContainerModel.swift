// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SwiftExtensions

/// Dictionary mapping ``TagKey`` enum cases to their string values.
public typealias TagKeyDictionary = [TagKey: String]

/// Shared interface for types that store audio metadata as ``TagKeyDictionary`` and custom tag dictionaries.
///
/// Provides default implementations for tag lookup, mutation, merging, and format-specific
/// setters (`set(taglibKey:value:)`, `set(id3Frame:value:)`, `set(infoFrame:value:)`).
/// Adopted by ``TagData``, ``TagProperties``, and ``TagPropertiesAV``.
public protocol TagPropertiesContainerModel: CustomStringConvertible {
    /// Standard tags keyed by ``TagKey`` (ID3v2, RIFF INFO, and other recognized formats).
    var tags: TagKeyDictionary { get set }

    /// Custom or unrecognized tags keyed by their raw string identifier.
    var customTags: [String: String] { get set }
}

extension TagPropertiesContainerModel {
    public subscript(key: TagKey) -> String? {
        get { tags[key] }
        set {
            tags[key] = newValue
        }
    }

    /// Returns `true` if a tag matching the given key's ID3 frame exists.
    public func contains(key: TagKey) -> Bool {
        tags.contains { $0.key.id3Frame == key.id3Frame }
    }

    /// Returns `true` if all of the given tag keys are present.
    public func contains(keys: [TagKey]) -> Bool {
        for key in keys {
            guard contains(key: key) else { return false }
        }

        return true
    }

    public var description: String {
        let tagsStrings = tags.map {
            let key: TagKey = $0.key
            return "\(key.descriptionKey) = \($0.value)"
        }

        let customStrings = customTags.map {
            let key: String = $0.key

            if let frame = ID3FrameKey(rawValue: key) {
                return "\(frame.displayName) (Custom ID3: \(frame.value)) = \($0.value)"

            } else if let frame = InfoFrameKey(rawValue: key) {
                return "\(frame.displayName) (Custom INFO: \(frame.value)) = \($0.value)"

            } else {
                return "\(key) (Custom) = \($0.value)"
            }
        }

        let strings = tagsStrings + customStrings

        return strings.sorted().joined(separator: "\n")
    }
}

extension TagPropertiesContainerModel {
    /// Returns the value of a standard tag, or `nil` if not present.
    public func tag(for tagKey: TagKey) -> String? {
        tags[tagKey]
    }

    /// Returns the value of a custom tag by its raw string key, or `nil` if not present.
    public func customTag(for key: String) -> String? {
        customTags[key]
    }

    /// Sets a standard tag value. Pass `nil` to remove the tag.
    public mutating func set(tag key: TagKey, value: String?) {
        tags[key] = value
    }

    /// Sets a custom tag value by its raw string key. Pass `nil` to remove it.
    public mutating func set(customTag key: String, value: String?) {
        customTags[key] = value
    }

    /// Removes a single standard tag.
    public mutating func remove(tag key: TagKey) {
        tags.removeValue(forKey: key)
    }

    /// Removes a single custom tag by its raw string key.
    public mutating func remove(customTag key: String) {
        customTags.removeValue(forKey: key)
    }

    /// Removes all standard and custom tags.
    public mutating func removeAll() {
        tags.removeAll()
        customTags.removeAll()
    }

    /// Merges an array of tag dictionaries, keeping the first value encountered for duplicate keys.
    public mutating func merging(tags array: [TagKeyDictionary]) {
        var mergedTags: TagKeyDictionary = .init()

        for item in array {
            // keep old value if duplicate key
            mergedTags = mergedTags.merging(item, uniquingKeysWith: { old, _ in old })
        }

        tags = mergedTags
    }

    /// Merges an array of custom tag dictionaries, keeping the first value encountered for duplicate keys.
    public mutating func merging(customTags array: [[String: String]]) {
        var mergedCustomTags: [String: String] = .init()

        for item in array {
            mergedCustomTags = mergedCustomTags.merging(item, uniquingKeysWith: { old, _ in old })
        }

        customTags = mergedCustomTags
    }
}

extension TagPropertiesContainerModel {
    /// Sets a tag by its TagLib property key (e.g., "TITLE").
    /// Routes to ``tags`` if a matching ``TagKey`` exists, otherwise to ``customTags``.
    /// Control characters are stripped and the value is trimmed.
    public mutating func set(taglibKey key: String, value: String) {
        let value = value.removing(.controlCharacters).trimmed

        guard let frame = TagKey(taglibKey: key) else {
            customTags[key] = value
            return
        }

        tags[frame] = value
    }

    /// Sets a tag by its ``ID3FrameKey``. User-defined frames (TXXX) are routed to ``customTags``.
    /// Control characters are stripped and the value is trimmed.
    public mutating func set(id3Frame key: ID3FrameKey, value: String) {
        let value = value.removing(.controlCharacters).trimmed

        if key == .userDefined {
            customTags[key.rawValue] = value
            return
        }

        guard let frame = TagKey(id3Frame: key) else {
            customTags[key.taglibKey] = value
            return
        }

        tags[frame] = value
    }

    /// Sets a tag by its ``InfoFrameKey``. Routes to ``tags`` if a matching ``TagKey`` exists.
    /// Control characters are stripped and the value is trimmed.
    public mutating func set(infoFrame key: InfoFrameKey, value: String) {
        let value = value.removing(.controlCharacters).trimmed

        if let frame = TagKey(infoFrame: key) {
            tags[frame] = value
            return
        }

        customTags[key.taglibKey] = value
    }
}
