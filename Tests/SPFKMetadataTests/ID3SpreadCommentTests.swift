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
        try description.save(dirtyFlags: [.tags])

        let after = try comments(in: url).filter(\.description.isEmpty).map { "\($0.language) | \($0.text)" }
        #expect(after.sorted() == before.sorted())
    }

    @Test func anUneditedPairKeepsItsPositions() async throws {
        let url = try plantedMP3()

        // A v2.3 render appends the frames it converts from v2.4 ones, whatever was edited.
        let convertedIDs: Set<String> = ["TORY", "TYER", "TDAT", "TIME", "IPLS", "TCON"]

        func undescribedCommentIndexes() throws -> [Int] {
            let frames = try #require(try ID3v2Frames.tag(in: url)).frames.filter { !convertedIDs.contains($0.id) }
            return try frames.indices.filter {
                try frames[$0].id == "COMM" && ID3v2Frames.Comment(frames[$0].body).description.isEmpty
            }
        }

        let before = try undescribedCommentIndexes()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Edited Title"
        try description.save(dirtyFlags: [.tags])

        let after = try undescribedCommentIndexes()
        #expect(after == before)
    }

    @Test func anUneditedPairKeepsTheID3v1Comment() async throws {
        let url = try plantedMP3()
        let first = try #require(try comments(in: url).first { $0.description.isEmpty })

        func field(_ string: String, _ length: Int) -> Data {
            let bytes = Data(string.utf8.prefix(length))
            return bytes + Data(count: length - bytes.count)
        }

        // ID3v1.1: a 28-byte comment, a zero byte, then the track.
        let id3v1 = Data("TAG".utf8) + field("Stonehenge", 30) + field("Spinal Tap", 30) + field("This Is Spinal Tap", 30)
            + field("1984", 4) + field(first.text, 28) + Data([0, 9, 255])
        try (Data(contentsOf: url) + id3v1).write(to: url)
        try #require(try ID3v2Frames.hasID3v1(in: url))

        func id3v1Comment() throws -> Data {
            let tag = Data(try Data(contentsOf: url).suffix(128))
            return Data(tag[97 ..< 125].prefix { $0 != 0 })
        }

        let before = try id3v1Comment()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Edited Title"
        try description.save(dirtyFlags: [.tags])

        #expect(try ID3v2Frames.hasID3v1(in: url))
        let after = try id3v1Comment()
        #expect(after == before)
    }

    @Test func anEditedPairIsWrittenAsTheOneCommentTyped() async throws {
        let url = try plantedMP3()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.comment] = "Edited"
        try description.save(dirtyFlags: [.tags])

        let all = try comments(in: url)
        #expect(all.filter(\.description.isEmpty).map(\.text) == ["Edited"])
        #expect(all.filter { !$0.description.isEmpty }.map(\.language) == ["eng"])
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.comment] == "Edited")
    }
}
