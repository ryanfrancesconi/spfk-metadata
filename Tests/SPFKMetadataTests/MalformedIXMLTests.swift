// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// An iXML chunk that does not parse is kept exactly as read, and a save that does not edit it
/// writes the same bytes back.
@Suite(.tags(.file))
final class MalformedIXMLTests: BinTestCase {
    /// `PROJECT` is never closed.
    static let malformed = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BWFXML><PROJECT>Unclosed<NOTE>Kept</NOTE></BWFXML>"

    @Test func aWAVKeepsUnparseableIXMLThroughATagSave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.id == "iXML" }
            chunks.append(RIFFChunks.Chunk(id: "iXML", payload: Data(Self.malformed.utf8)))
        }

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.iXMLMetadata == Self.malformed)

        description.set(tag: .title, value: "Edited")
        try description.save(dirtyFlags: [.tags])

        #expect(try RIFFChunks(contentsOf: url).first("iXML")?.payload == Data(Self.malformed.utf8))
    }

    @Test func aFLACKeepsUnparseableIXMLThroughATagSave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        try FLACBlockWriter.rewrite(url) { blocks in
            blocks.append(FLACBlockWriter.riff(id: "iXML", payload: Data(Self.malformed.utf8)))
        }

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.iXMLMetadata == Self.malformed)

        description.set(tag: .title, value: "Edited")
        try description.save(dirtyFlags: [.tags])

        let stored = try FLACBlocks(contentsOf: url).blocks.compactMap { try $0.riffChunk() }.first { $0.id == "iXML" }?.payload
        #expect(stored == Data(Self.malformed.utf8))
    }
}
