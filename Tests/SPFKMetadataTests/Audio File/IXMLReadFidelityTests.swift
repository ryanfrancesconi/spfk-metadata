// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AEXML
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// An iXML value's edge whitespace and line breaks survive a read and an unrelated save.
@Suite(.tags(.file))
class IXMLReadFidelityTests: BinTestCase {
    private static let note = "  a\nb  "
    private static let chunk = "<BWFXML><PROJECT>p</PROJECT><NOTE>\(note)</NOTE></BWFXML>"

    /// Parses without AEXML's default trimming, so the assertion sees the text as stored.
    private func noteText(in xml: String?) throws -> String? {
        var options = AEXMLOptions()
        options.parserSettings.shouldTrimWhitespace = false
        let doc = try AEXMLDocument(xml: try #require(xml), options: options)
        return doc.root["NOTE"].value
    }

    private func rawChunk(at url: URL) -> String? {
        if AudioFileType(url: url) == .flac {
            let file = FlacFileC(path: url.path)
            #expect(file.load())
            return file.iXML
        }

        let file = WaveFileC(path: url.path)
        #expect(file.load())
        return file.iXML
    }

    @Test(arguments: [TestBundleResources.shared.tabla_wav, TestBundleResources.shared.tabla_flac])
    func noteWhitespaceSurvivesReadAndSave(url: URL) async throws {
        let tmpfile = try copyToBin(url: url)

        var seeded = try await MetaAudioFileDescription(parsing: tmpfile)
        seeded.iXMLMetadata = Self.chunk
        try seeded.save()
        #expect(try noteText(in: rawChunk(at: tmpfile)) == Self.note)

        var parsed = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(try noteText(in: parsed.iXMLMetadata) == Self.note)

        parsed.set(tag: .title, value: "Edited")
        try parsed.save()

        #expect(try noteText(in: rawChunk(at: tmpfile)) == Self.note)
    }
}
