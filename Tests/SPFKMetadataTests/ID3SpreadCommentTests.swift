// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Two undescribed `COMM` frames read as one comment joined with a space.
@Suite(.tags(.file))
final class ID3SpreadCommentTests: BinTestCase {
    private func comments(in url: URL) throws -> [ID3v2Frames.Comment] {
        let tag = try #require(try ID3v2Frames.tag(in: url))
        return try tag.frames("COMM").map { try ID3v2Frames.Comment($0.body) }
    }

    private func plantedMP3() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try SafetyNetID3Plant.plant(in: url)
        try #require(try comments(in: url).filter(\.description.isEmpty).count == 2)
        return url
    }

    @Test func anUneditedPairKeepsBothFramesAndLanguages() async throws {
        let url = try plantedMP3()
        let before = try comments(in: url).filter(\.description.isEmpty).map { "\($0.language) | \($0.text)" }

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Edited Title"
        try description.save(dirtyFlags: [.metadata])

        let after = try comments(in: url).filter(\.description.isEmpty).map { "\($0.language) | \($0.text)" }
        #expect(after.sorted() == before.sorted())
    }

    @Test func anEditedPairIsWrittenAsTheOneCommentTyped() async throws {
        let url = try plantedMP3()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.comment] = "Edited"
        try description.save(dirtyFlags: [.metadata])

        let all = try comments(in: url)
        #expect(all.filter(\.description.isEmpty).map(\.text) == ["Edited"])
        #expect(all.filter { !$0.description.isEmpty }.map(\.language) == ["eng"])
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.comment] == "Edited")
    }
}
