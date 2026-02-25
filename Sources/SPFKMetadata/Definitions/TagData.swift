import Foundation
import SPFKBase
import SPFKUtils

/// Thin wrapper to provide a keyed dictionary of known tags: TagKeyDictionary and
/// an overflow customTags value that unmatched keys found will be placed into.
public struct TagData: TagPropertiesContainerModel, Hashable, Codable, Serializable, Sendable {
    public var isEmpty: Bool {
        tags.isEmpty && customTags.isEmpty
    }

    /// Known ID3 tags
    public var tags: TagKeyDictionary

    /// TXXX, Unoffical, uncommon tags found in this file
    /// Any tags that didn't match to a `TagKey` value
    public var customTags: [String: String]

    public init(tags: TagKeyDictionary = .init(), customTags: [String: String] = .init()) {
        self.tags = tags
        self.customTags = customTags
    }

    public mutating func removeAll() {
        tags.removeAll()
        customTags.removeAll()
    }

    public mutating func remove(data: TagData) {
        for key in data.tags.keys {
            tags.removeValue(forKey: key)
        }

        for key in data.customTags.keys {
            customTags.removeValue(forKey: key)
        }
    }
}

extension [TagData] {
    /// Combines multiple TagData instances into one using the passed in merge scheme
    public func merge(scheme: DictionaryMergeScheme = .preserve) -> TagData {
        let allTags = compactMap(\.tags)
        let allCustomTags = compactMap(\.customTags)

        var mergedTags: TagKeyDictionary = .init()
        var mergedCustomTags: [String: String] = .init()

        for item in allTags {
            mergedTags = mergedTags.merging(item, uniquingKeysWith: { old, new in
                switch scheme {
                case .preserve:
                    old
                case .replace:
                    new
                case .combine:
                    old + ", \(new)" // string delimiter ", "
                }
            })
        }

        for item in allCustomTags {
            mergedCustomTags = mergedCustomTags.merging(item, uniquingKeysWith: { old, new in
                switch scheme {
                case .preserve:
                    old
                case .replace:
                    new
                case .combine:
                    old + ", \(new)"
                }
            })
        }

        return TagData(tags: mergedTags, customTags: mergedCustomTags)
    }
}
