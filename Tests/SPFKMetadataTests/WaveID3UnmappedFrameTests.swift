// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// ID3 frames the PropertyMap cannot express stay in a WAV's tag as they are, with no `TXXX` copy.
@Suite(.tags(.file))
final class WaveID3UnmappedFrameTests: BinTestCase {
    private let privBody = Data("com.example.test".utf8) + Data([0, 0x68, 0x69, 0xE9, 0x00, 0xFF, 0x41])
    private let ufidBody = Data("http://example.com/id".utf8) + Data([0]) + Data("abc123".utf8)

    private func fixture(extraFrames: [Data] = []) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try ID3v24TagBuilder.replaceWAVTag(in: url, with: [
            ID3v24TagBuilder.tit2(latin1: "Before"),
            ID3v24TagBuilder.frame(id: "PRIV", body: privBody),
            ID3v24TagBuilder.frame(id: "UFID", body: ufidBody),
        ] + extraFrames)
        return url
    }

    /// The frames of the WAV's `ID3 ` chunk, read from its bytes.
    private func id3Frames(in url: URL) throws -> [(id: String, body: Data)] {
        let payload = try #require(try IFFChunks.payload(id: "ID3 ", in: url, bigEndian: false))
        let tagURL = bin.appendingPathComponent("\(UUID().uuidString).id3")
        try payload.write(to: tagURL)
        return try ID3v2Frames.frames(in: tagURL)
    }

    /// A `TXXX` body's description: an encoding byte, then text up to the encoding's terminator.
    private func txxxDescription(_ body: Data) -> String? {
        guard let encoding = body.first else { return nil }
        let text = Data(body.dropFirst())

        switch encoding {
        case 0, 3:
            let end = text.firstIndex(of: 0) ?? text.endIndex
            return String(data: text[..<end], encoding: encoding == 0 ? .isoLatin1 : .utf8)
        default:
            let units = stride(from: 0, to: text.count - 1, by: 2).map {
                UInt16(text[text.startIndex + $0]) | UInt16(text[text.startIndex + $0 + 1]) << 8
            }
            return String(decoding: units.prefix { $0 != 0 }.drop { $0 == 0xFEFF }, as: UTF16.self)
        }
    }

    private func expectUnmappedFramesIntact(in url: URL) throws {
        let frames = try id3Frames(in: url)
        let descriptions = frames.filter { $0.id == "TXXX" }.compactMap { txxxDescription($0.body) }

        #expect(frames.filter { $0.id == "PRIV" }.map(\.body) == [privBody])
        #expect(frames.filter { $0.id == "UFID" }.map(\.body) == [ufidBody])
        #expect(Set(descriptions).isDisjoint(with: ["PRIV", "PRIVATE", "UFID"]), "\(descriptions)")
    }

    @Test func unmappedFramesAreNotReadAsCustomTags() async throws {
        let description = try await MetaAudioFileDescription(parsing: fixture())

        #expect(description.tagProperties[.title] == "Before")
        #expect(description.tagProperties.customTags["PRIVATE"] == nil)
        #expect(description.tagProperties.customTags["UFID"] == nil)
    }

    @Test func tagSaveKeepsUnmappedFramesAsTheyAre() async throws {
        let url = try fixture()
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "After"
        try description.save(dirtyFlags: [.tags])

        try expectUnmappedFramesIntact(in: url)
        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "After")
    }

    @Test func bextWriteKeepsUnmappedFramesAsTheyAre() throws {
        let url = try fixture()
        var bext = BEXTDescription()
        bext.originator = "Test"
        try BEXTDescription.write(bextDescription: bext, to: url)

        try expectUnmappedFramesIntact(in: url)
    }

    @Test func lyricsAreStillRead() async throws {
        let uslt = ID3v24TagBuilder.frame(id: "USLT", body: Data([0]) + Data("eng".utf8) + Data([0]) + Data("la la".utf8))
        let description = try await MetaAudioFileDescription(parsing: fixture(extraFrames: [uslt]))

        #expect(description.tagProperties[.lyrics] == "la la")
    }
}
