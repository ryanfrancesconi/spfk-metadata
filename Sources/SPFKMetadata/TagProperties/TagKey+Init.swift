// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

// MARK: - Static Lookup Tables

extension TagKey {
    private static let taglibKeyMap: [String: TagKey] = {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.taglibKey, $0) })
    }()

    private static let displayNameMap: [String: TagKey] = {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.displayName, $0) })
    }()

    nonisolated(unsafe) private static let id3FrameMap: [ID3FrameKey: TagKey] = {
        var map = [ID3FrameKey: TagKey]()
        for key in allCases {
            // first match wins, matching previous behavior
            if map[key.id3Frame] == nil {
                map[key.id3Frame] = key
            }
        }
        return map
    }()

    nonisolated(unsafe) private static let infoFrameMap: [InfoFrameKey: TagKey] = {
        var map = [InfoFrameKey: TagKey]()
        for key in allCases {
            if let frame = key.infoFrame, map[frame] == nil {
                map[frame] = key
            }
            for alt in key.infoAlternates where map[alt] == nil {
                map[alt] = key
            }
        }
        return map
    }()
}

// MARK: - Initializers

extension TagKey {
    public init?(taglibKey: String) {
        guard let match = Self.taglibKeyMap[taglibKey] else { return nil }
        self = match
    }

    public init?(displayName: String) {
        guard let match = Self.displayNameMap[displayName] else { return nil }
        self = match
    }

    public init?(id3Frame: ID3FrameKey) {
        guard let match = Self.id3FrameMap[id3Frame] else { return nil }
        self = match
    }

    public init?(infoFrame: InfoFrameKey) {
        guard let match = Self.infoFrameMap[infoFrame] else { return nil }
        self = match
    }
}
