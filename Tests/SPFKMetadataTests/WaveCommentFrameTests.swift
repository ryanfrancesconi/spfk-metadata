// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A WAV's comment is its undescribed `COMM`; a described one is another app's and is kept beside it.
@Suite(.tags(.file))
final class WaveCommentFrameTests: BinTestCase {
    private let normalization = " 00000214 00000203 00001D6C 00001C2A"

    private func comment(language: String, description: String, text: String) -> Data {
        ID3v24TagBuilder.frame(id: "COMM", body: Data([0]) + Data(language.utf8) + Data(description.utf8) + Data([0]) + Data(text.utf8))
    }

    private func fixture() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try ID3v24TagBuilder.replaceWAVTag(in: url, with: [
            ID3v24TagBuilder.tit2(latin1: "Before"),
            comment(language: "eng", description: "", text: "Mine"),
            comment(language: "eng", description: "iTunNORM", text: normalization),
        ])
        return url
    }

    private func comments(in url: URL) throws -> [ID3v2Frames.Comment] {
        let payload = try #require(try IFFChunks.payload(id: "ID3 ", in: url, bigEndian: false))
        let tag = try #require(try ID3v2Frames.tag(in: payload))
        return try tag.frames("COMM").map { try ID3v2Frames.Comment($0.body) }
    }

    @Test func undescribedCommentIsTheFilesComment() async throws {
        let description = try await MetaAudioFileDescription(parsing: fixture())

        #expect(description.tagProperties[.comment] == "Mine")
    }

    @Test func titleSaveKeepsTheCommentAndTheDescribedFrame() async throws {
        let url = try fixture()
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "After"
        try description.save(dirtyFlags: [.tags])

        let saved = try comments(in: url).map { "\($0.language) | \($0.description) | \($0.text)" }
        #expect(saved.sorted() == ["eng |  | Mine", "eng | iTunNORM | \(normalization)"])

        let info = try RIFFChunks(contentsOf: url).infoItems()
        #expect(info.filter { $0.id == "ICMT" }.map(\.value) == ["Mine"])
    }
}
