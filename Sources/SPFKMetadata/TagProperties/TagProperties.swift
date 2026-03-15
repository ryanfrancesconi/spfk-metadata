// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKUtils

/// Format-agnostic tag container backed by ``TagData``.
///
/// Stores ID3v2, RIFF INFO, Vorbis Comment, and custom tag fields in a unified
/// ``TagData`` container. File I/O via TagLib is provided in `TagProperties+IO`.
public struct TagProperties: Hashable, Codable, Sendable {
    /// The underlying tag storage. Use ``TagPropertiesContainerModel`` accessors for mutation.
    public var data = TagData()

    /// Audio format properties (sample rate, channels, etc.) read alongside the tags by TagLib.
    public var audioProperties: AudioFormatProperties?

    var tagLibPropertyMap: [String: String] {
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

