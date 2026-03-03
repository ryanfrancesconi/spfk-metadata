// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SwiftExtensions

public typealias TagKeyDictionary = [TagKey: String]

public protocol TagPropertiesContainerModel: CustomStringConvertible {
    /// Official ID3 or conventional tags found in this file
    var tags: TagKeyDictionary { get set }

    /// Unoffical, other custom tags found in this file
    var customTags: [String: String] { get set }
}

extension TagPropertiesContainerModel {
    public subscript(key: TagKey) -> String? {
        get { tags[key] }
        set {
            tags[key] = newValue
        }
    }

    public func contains(key: TagKey) -> Bool {
        tags.contains { $0.key.id3Frame == key.id3Frame }
    }

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
    public func tag(for tagKey: TagKey) -> String? {
        tags[tagKey]
    }

    public func customTag(for key: String) -> String? {
        customTags[key]
    }

    public mutating func set(tag key: TagKey, value: String?) {
        tags[key] = value
    }

    public mutating func set(customTag key: String, value: String?) {
        customTags[key] = value
    }

    public mutating func remove(tag key: TagKey) {
        tags.removeValue(forKey: key)
    }

    public mutating func remove(customTag key: String) {
        customTags.removeValue(forKey: key)
    }

    public mutating func removeAll() {
        tags.removeAll()
        customTags.removeAll()
    }

    public mutating func merging(tags array: [TagKeyDictionary]) {
        var mergedTags: TagKeyDictionary = .init()

        for item in array {
            // keep old value if duplicate key
            mergedTags = mergedTags.merging(item, uniquingKeysWith: { old, _ in old })
        }

        tags = mergedTags
    }

    public mutating func merging(customTags array: [[String: String]]) {
        var mergedCustomTags: [String: String] = .init()

        for item in array {
            mergedCustomTags = mergedCustomTags.merging(item, uniquingKeysWith: { old, _ in old })
        }

        customTags = mergedCustomTags
    }
}

extension TagPropertiesContainerModel {
    /// "TITLE": "Hello"
    public mutating func set(taglibKey key: String, value: String) {
        let value = value.removing(.controlCharacters).trimmed

        guard let frame = TagKey(taglibKey: key) else {
            customTags[key] = value
            return
        }

        tags[frame] = value
    }

    /// .title = Hello
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

    public mutating func set(infoFrame key: InfoFrameKey, value: String) {
        let value = value.removing(.controlCharacters).trimmed

        if let frame = TagKey(infoFrame: key) {
            tags[frame] = value
            return
        }

        customTags[key.taglibKey] = value
    }
}
