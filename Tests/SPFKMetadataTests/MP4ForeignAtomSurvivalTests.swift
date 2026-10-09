// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A title save keeps every `ilst` item the PropertyMap has no key for: media kind, content
/// rating, store IDs, and freeform atoms owned by other applications.
@Suite(.tags(.file))
final class MP4ForeignAtomSurvivalTests: BinTestCase {
    private typealias Item = MP4ItemListBuilder.Item

    /// `stik`, `rtng` and `plID` are signed integers (type 21); freeform values are UTF-8 (type 1).
    private func plantedItems(mediaKind: UInt8) -> [Item] {
        [
            Item(key: "stik", type: 21, value: [mediaKind]),
            Item(key: "rtng", type: 21, value: [1]),
            Item(key: "plID", type: 21, value: [0, 0, 0, 0, 0x12, 0x34, 0x56, 0x78]),
            Item(key: "----:com.example.app:Foo", type: 1, value: Array("bar".utf8)),
            Item(key: "----:com.apple.iTunes:CUSTOM", type: 1, value: Array("custom value".utf8)),
        ]
    }

    private func plant(_ items: [Item], in url: URL) throws {
        let boxes = items.map { item in
            let parts = item.key.split(separator: ":", maxSplits: 2).map(String.init)

            return parts.count == 3
                ? MP4ItemListBuilder.freeform(mean: parts[1], name: parts[2], value: String(decoding: item.value, as: UTF8.self))
                : MP4ItemListBuilder.item(item.key, type: item.type, value: item.value)
        }

        try MP4ItemListBuilder.append(boxes, to: url)
    }

    private func assertItemsSurviveATitleSave(source: URL, mediaKind: UInt8) async throws {
        let url = try copyToBin(url: source)
        let planted = plantedItems(mediaKind: mediaKind)
        try plant(planted, in: url)

        let before = try MP4ItemListBuilder.items(in: url)
        for item in planted {
            try #require(before.contains(item), "not planted: \(item)")
        }

        let asset = AVURLAsset(url: url)
        try #require(try await asset.load(.isPlayable))
        try #require(try await asset.load(.duration).seconds > 0)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Saved Title"
        try description.save(dirtyFlags: [.tags])

        let after = try MP4ItemListBuilder.items(in: url)
        for item in planted {
            #expect(after.first { $0.key == item.key } == item, "\(item.key) did not survive the save")
        }

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Saved Title")
    }

    @Test func foreignItemsSurviveATitleSaveInM4A() async throws {
        try await assertItemsSurviveATitleSave(source: TestBundleResources.shared.tabla_m4a, mediaKind: 1)
    }

    /// `stik` 2 is what makes Apple Books and Music treat the file as an audiobook.
    @Test func foreignItemsSurviveATitleSaveInM4B() async throws {
        try await assertItemsSurviveATitleSave(source: TestBundleResources.shared.sine_m4b, mediaKind: 2)
    }
}
