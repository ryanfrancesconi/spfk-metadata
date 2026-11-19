// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A `LIST` too short to name its type holds nothing, and ffmpeg refuses a file carrying one. A
/// save that writes a `LIST` drops them; another application's typed `LIST` is kept.
@Suite(.tags(.file))
final class WaveUntypedListTests: BinTestCase {
    private typealias Chunk = RIFFChunks.Chunk

    private let foreignList = RIFFChunkBuilder.list("abcd", [Chunk(id: "abcd", payload: Data("kept".utf8))])

    private func fixture() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try RIFFChunkBuilder.rewrite(url) { chunks in
            let index = try #require(chunks.firstIndex { $0.id == "data" }) + 1
            chunks.insert(contentsOf: [
                Chunk(id: "LIST", payload: Data()),
                Chunk(id: "LIST", payload: Data("ab".utf8)),
                foreignList,
            ], at: index)
        }
        return url
    }

    @Test func aTagSaveDropsUntypedListsAndKeepsTheAudio() async throws {
        let url = try fixture()
        let audioBefore = try #require(try RIFFChunks(contentsOf: url).first("data")).payload

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "After"
        try description.save(dirtyFlags: [.tags])

        let riff = try RIFFChunks(contentsOf: url)
        let lists = riff.chunks.filter { $0.id == "LIST" }

        #expect(lists.allSatisfy { $0.payload.count >= 4 })
        #expect(lists.contains { $0.payload == foreignList.payload })
        #expect(lists.contains { $0.payload.starts(with: Data("INFO".utf8)) })
        #expect(riff.first("data")?.payload == audioBefore)
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "After")
    }
}
