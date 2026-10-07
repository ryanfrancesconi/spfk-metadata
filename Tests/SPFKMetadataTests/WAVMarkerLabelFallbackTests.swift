// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A `labl` is read as UTF-8, then Windows-1252, then Latin-1, which maps every byte, so no
/// marker name is ever lost to its encoding.
@Suite(.tags(.file))
final class WAVMarkerLabelFallbackTests: BinTestCase {
    /// Valid in neither UTF-8 (a bare continuation byte) nor Windows-1252 (0x81 and 0x8D are
    /// undefined there).
    static let label = Data("Cue ".utf8) + Data([0x81, 0x8D, 0xE9])

    @Test func aLabelNeitherUTF8NorWindows1252IsReadAsLatin1() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let cueID = try #require(try RIFFChunks(contentsOf: url).cuePoints().first?.id)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            let labl = RIFFChunks.Chunk(id: "labl", payload: RIFFChunkBuilder.le32(Int(cueID)) + Self.label + Data([0]))
            chunks.removeAll { $0.listType == "adtl" }
            chunks.append(RIFFChunkBuilder.list("adtl", [labl]))
        }

        let description = try await MetaAudioFileDescription(parsing: url)
        let expected = try #require(String(data: Self.label, encoding: .isoLatin1))

        #expect(description.markerCollection.markerDescriptions.first?.name == expected)
    }
}
