// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation

/// Read-only tag reader using AVFoundation instead of TagLib.
///
/// Parses ID3 metadata via `AVURLAsset` without any native library dependencies. Write support
/// is not available through AVFoundation. Slower than ``TagProperties`` due to AVFoundation's
/// asynchronous loading model. Useful as a fallback or when TagLib is not needed.
public struct TagPropertiesAV: Hashable, Codable, Sendable {
    /// The parsed tag data.
    public var data = TagData()

    /// Reads ID3 tags from the audio file at the given URL using AVFoundation.
    /// - Parameter url: URL to the audio file.
    public init(url: URL) async throws {
        let asset = AVURLAsset(url: url)

        let metadata = try await Self.loadMetadata(from: asset)

        for item in metadata {
            guard let id3key = item.key as? String,
                  let id3Frame = ID3FrameKey(rawValue: id3key),
                  let value = try? await Self.loadValue(for: item) else { continue }

            data.set(id3Frame: id3Frame, value: value)
        }
    }

    private static func loadMetadata(from asset: AVURLAsset) async throws -> [AVMetadataItem] {
        try await asset.loadMetadata(for: .id3Metadata)
    }

    private static func loadValue(for item: AVMetadataItem) async throws -> String? {
        try await item.load(.value) as? String
    }
}

extension TagPropertiesAV: TagPropertiesContainerModel {
    public var tags: TagKeyDictionary {
        get { data.tags }
        set { data.tags = newValue }
    }

    public var customTags: [String: String] {
        get { data.customTags }
        set { data.customTags = newValue }
    }
}
