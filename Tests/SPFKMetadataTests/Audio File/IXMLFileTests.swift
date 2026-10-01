// Copyright Ryan Francesconi. All Rights Reserved.

import AEXML
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
final class IXMLFileTests: BinTestCase {
    @Test func parseFromWaveFile() async throws {
        let url = TestBundleResources.shared.ixml_chunk
        let file = WaveFileC(path: url.path)
        #expect(file.load())

        let ixmlString = try #require(file.iXML)
        _ = try IXMLMetadata(xml: ixmlString)
    }

    @Test func malformedIXMLIsLeftUntouchedByUCSSync() {
        let malformed = "<BWFXML><USER><CATEGORY>AMBIENCE</CATEGORY></USER>"
        var description = MetaAudioFileDescription(
            url: TestBundleResources.shared.tabla_wav, fileType: .wav, iXMLMetadata: malformed
        )

        description.syncUCSToIXML(category: "EXPLOSIONS", subCategory: "DESIGNED", catID: "EXPLDsgn")

        #expect(description.iXMLMetadata == malformed)
    }

    @Test func ucsSyncCreatesIXMLWhenAbsent() throws {
        var description = MetaAudioFileDescription(url: TestBundleResources.shared.tabla_wav, fileType: .wav)

        description.syncUCSToIXML(category: "EXPLOSIONS", subCategory: "DESIGNED", catID: "EXPLDsgn")

        let xml = try #require(description.iXMLMetadata)
        #expect(try IXMLMetadata(xml: xml).ucsFields?.catID == "EXPLDsgn")
    }
}
