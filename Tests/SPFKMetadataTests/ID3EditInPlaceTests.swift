// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// An edited ID3v2 frame another application wrote keeps its language and description.
@Suite(.tags(.file))
final class ID3EditInPlaceTests: BinTestCase {
    private func plantedMP3() throws -> URL {
        typealias Builder = ID3v24TagBuilder

        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try Builder.replaceTagWithVersion3(in: url, frames: [
            Builder.version3TextFrame(id: "TIT2", values: ["Title"]),
            Builder.version3Comment(id: "COMM", language: "deu", description: "", text: "hallo"),
            Builder.version3UserText(description: "MyTag", values: ["old"]),
        ])
        return url
    }

    private func frames(_ id: String, in url: URL) throws -> [ID3v2Frames.Frame] {
        try #require(try ID3v2Frames.tag(in: url)).frames(id)
    }

    @Test func anEditedCommentKeepsItsLanguage() async throws {
        let url = try plantedMP3()
        let commentFrame = try #require(try frames("COMM", in: url).first)
        try #require(commentFrame.body.first == ID3v2Frames.TextEncoding.latin1.rawValue)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.comment] = "Łódź ✓"
        try description.save(dirtyFlags: [.tags])

        let comments = try frames("COMM", in: url).map { try ID3v2Frames.Comment($0.body) }
        #expect(comments.map { "\($0.language) | \($0.description) | \($0.text)" } == ["deu |  | Łódź ✓"])
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.comment] == "Łódź ✓")
    }

    @Test func anEditedCustomTagKeepsItsDescription() async throws {
        let url = try plantedMP3()

        var description = try await MetaAudioFileDescription(parsing: url)
        try #require(description.tagProperties.customTags["MYTAG"] == "old")
        description.tagProperties.customTags["MYTAG"] = "new"
        try description.save(dirtyFlags: [.tags])

        let userTexts = try frames("TXXX", in: url).map { try ID3v2Frames.UserText($0.body) }
        #expect(userTexts.filter { $0.description.uppercased() == "MYTAG" }.map(\.description) == ["MyTag"])
        #expect(userTexts.first { $0.description == "MyTag" }?.values == ["new"])
    }
}
