// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// INFO is the mirror of a WAV's tags: an item `InfoFrameKey` has no name for is read as a custom
/// tag under its own ID, and is kept, changed or removed as that tag is.
@Suite(.tags(.file))
final class WaveINFOMirrorTests: BinTestCase {
    private func wave(withInfo items: [String: String]) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" }
            let subchunks = items.sorted { $0.key < $1.key }.map { RIFFChunks.Chunk(id: $0.key, payload: Data(($0.value + "\0").utf8)) }
            chunks.append(RIFFChunkBuilder.list("INFO", subchunks))
        }

        return url
    }

    @Test func unknownItemIsReadAsCustomTag() async throws {
        let url = try wave(withInfo: ["IFRM": "Frames"])

        let parsed = try await MetaAudioFileDescription(parsing: url)
        #expect(parsed.tagProperties.customTags["IFRM"] == "Frames")

        let read = try TagProperties(url: url)
        #expect(read.customTags["IFRM"] == "Frames")
    }

    @Test func unknownItemFollowsItsTagThroughSave() async throws {
        let url = try wave(withInfo: ["IFRM": "Removed", "IXYZ": "Kept", "IZZZ": "Old"])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties.customTags["IFRM"] = nil
        description.tagProperties.customTags["IZZZ"] = "New"
        try description.save(dirtyFlags: [.tags])

        let info = Dictionary(uniqueKeysWithValues: try RIFFChunks(contentsOf: url).infoItems().map { ($0.id, $0.value) })
        #expect(info["IFRM"] == nil)
        #expect(info["IXYZ"] == "Kept")
        #expect(info["IZZZ"] == "New")

        let reparsed = try await MetaAudioFileDescription(parsing: url)
        #expect(reparsed.tagProperties.customTags["IFRM"] == nil)
        #expect(reparsed.tagProperties.customTags["IXYZ"] == "Kept")
        #expect(reparsed.tagProperties.customTags["IZZZ"] == "New")
    }
}
