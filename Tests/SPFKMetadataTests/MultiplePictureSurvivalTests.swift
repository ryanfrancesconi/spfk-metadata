// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// Changing the front cover leaves a file's other pictures in place, as does a tags-only save.
@Suite(.tags(.file))
final class MultiplePictureSurvivalTests: BinTestCase {
    private struct Picture: Equatable {
        let type: UInt8
        let data: Data
    }

    private static let frontCover: UInt8 = 3
    private static let backCover: UInt8 = 4

    private var frontData: Data { get throws { try Data(contentsOf: TestBundleResources.shared.sharksandwich) } }
    private var backData: Data { get throws { try Data(contentsOf: TestBundleResources.shared.songbird) } }

    private func newFrontCover() throws -> TagPictureRef {
        try #require(TagPictureRef(url: TestBundleResources.shared.sharksandwich_heic, pictureDescription: "New Front", pictureType: "Front Cover"))
    }

    // MARK: - MP3

    /// Latin-1 encoding, MIME type, picture type, description, then the image.
    private func apic(type: UInt8, description: String, data: Data) -> Data {
        let body = Data([0]) + Data("image/jpeg".utf8) + Data([0, type]) + Data(description.utf8) + Data([0]) + data
        return ID3v24TagBuilder.frame(id: "APIC", body: body)
    }

    /// Assumes a Latin-1 or UTF-8 description, as `apic` writes and TagLib keeps.
    private func mp3Pictures(in url: URL) throws -> [Picture] {
        try ID3v2Frames.frames(in: url).filter { $0.id == "APIC" }.compactMap { frame in
            let body = [UInt8](frame.body)
            guard let mimeEnd = body.dropFirst().firstIndex(of: 0), mimeEnd + 1 < body.count else { return nil }

            let type = body[mimeEnd + 1]
            let rest = body[(mimeEnd + 2)...]
            let terminator = body[0] == 1 || body[0] == 2 ? 2 : 1
            guard let descEnd = rest.firstIndex(of: 0) else { return nil }

            return Picture(type: type, data: Data(body[(descEnd + terminator)...]))
        }
    }

    private func mp3WithTwoPictures() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        try ID3v24TagBuilder.replaceTag(in: url, with: [
            ID3v24TagBuilder.tit2(latin1: "Old Title"),
            apic(type: Self.frontCover, description: "Front", data: try frontData),
            apic(type: Self.backCover, description: "Back", data: try backData),
        ])

        let pictures = try mp3Pictures(in: url)
        try #require(pictures.contains(Picture(type: Self.frontCover, data: try frontData)))
        try #require(pictures.contains(Picture(type: Self.backCover, data: try backData)))

        return url
    }

    @Test func mp3BackCoverSurvivesAFrontCoverChange() async throws {
        let url = try mp3WithTwoPictures()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.imageDescription.pictureRef = try newFrontCover()
        try description.save(dirtyFlags: [.image])

        let pictures = try mp3Pictures(in: url)
        let back = Picture(type: Self.backCover, data: try backData)
        #expect(pictures.contains(back), "back cover lost; pictures: \(pictures.map(\.type))")
        #expect(pictures.contains { $0.data != (try? frontData) && $0.data != (try? backData) }, "new artwork not written")
        #expect(pictures.contains { $0.type == Self.frontCover }, "no front cover; picture types: \(pictures.map(\.type))")
    }

    @Test func mp3BackCoverSurvivesATitleSave() async throws {
        let url = try mp3WithTwoPictures()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Saved Title"
        try description.save(dirtyFlags: [.tags])

        let pictures = try mp3Pictures(in: url)
        #expect(pictures.contains(Picture(type: Self.frontCover, data: try frontData)))
        #expect(pictures.contains(Picture(type: Self.backCover, data: try backData)), "back cover lost; pictures: \(pictures.map(\.type))")

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Saved Title")
    }

    // MARK: - FLAC

    private static let pictureBlock: UInt8 = 6

    private func be32(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt32(value).bigEndian) { Data($0) }
    }

    /// Dimensions, depth and color count are left zero, which the format allows.
    private func pictureBlockBody(type: UInt8, description: String, data: Data) -> Data {
        let mime = Data("image/jpeg".utf8)
        let desc = Data(description.utf8)
        return be32(Int(type)) + be32(mime.count) + mime + be32(desc.count) + desc
            + Data(count: 16) + be32(data.count) + data
    }

    /// The metadata blocks after `fLaC`, and the offset where the audio frames begin.
    private func flacBlocks(_ bytes: [UInt8]) -> (blocks: [(type: UInt8, body: Data)], audio: Int) {
        var blocks: [(type: UInt8, body: Data)] = []
        var offset = 4

        while offset + 4 <= bytes.count {
            let header = bytes[offset]
            let length = bytes[offset + 1 ..< offset + 4].reduce(0) { $0 << 8 | Int($1) }
            blocks.append((header & 0x7F, Data(bytes[offset + 4 ..< offset + 4 + length])))
            offset += 4 + length
            if header & 0x80 != 0 { break }
        }

        return (blocks, offset)
    }

    private func flacPictures(in url: URL) throws -> [Picture] {
        try flacBlocks([UInt8](Data(contentsOf: url))).blocks.filter { $0.type == Self.pictureBlock }.map { block in
            let body = [UInt8](block.body)
            func u32(_ at: Int) -> Int { body[at ..< at + 4].reduce(0) { $0 << 8 | Int($1) } }

            let mimeLength = u32(4)
            let descOffset = 8 + mimeLength
            let dataLengthOffset = descOffset + 4 + u32(descOffset) + 16
            let dataStart = dataLengthOffset + 4

            return Picture(type: UInt8(u32(0)), data: Data(body[dataStart ..< dataStart + u32(dataLengthOffset)]))
        }
    }

    /// Replaces any PICTURE blocks with a front and a back cover, after STREAMINFO.
    private func flacWithTwoPictures() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        let bytes = try [UInt8](Data(contentsOf: url))
        let (existing, audio) = flacBlocks(bytes)

        var blocks = existing.filter { $0.type != Self.pictureBlock }
        blocks.insert(contentsOf: [
            (Self.pictureBlock, pictureBlockBody(type: Self.frontCover, description: "Front", data: try frontData)),
            (Self.pictureBlock, pictureBlockBody(type: Self.backCover, description: "Back", data: try backData)),
        ], at: 1)

        var rebuilt = Data("fLaC".utf8)
        for (index, block) in blocks.enumerated() {
            let last: UInt8 = index == blocks.count - 1 ? 0x80 : 0
            rebuilt += Data([last | block.type]) + be32(block.body.count).dropFirst() + block.body
        }
        rebuilt += Data(bytes[audio...])
        try rebuilt.write(to: url)

        let pictures = try flacPictures(in: url)
        try #require(pictures.contains(Picture(type: Self.frontCover, data: try frontData)))
        try #require(pictures.contains(Picture(type: Self.backCover, data: try backData)))

        return url
    }

    @Test func flacBackCoverSurvivesAFrontCoverChange() async throws {
        let url = try flacWithTwoPictures()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.imageDescription.pictureRef = try newFrontCover()
        try description.save(dirtyFlags: [.image])

        let pictures = try flacPictures(in: url)
        let back = Picture(type: Self.backCover, data: try backData)
        #expect(pictures.contains(back), "back cover lost; pictures: \(pictures.map(\.type))")
        #expect(pictures.contains { $0.data != (try? frontData) && $0.data != (try? backData) }, "new artwork not written")
        #expect(pictures.contains { $0.type == Self.frontCover }, "no front cover; picture types: \(pictures.map(\.type))")
    }

    @Test func flacBackCoverSurvivesATitleSave() async throws {
        let url = try flacWithTwoPictures()

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Saved Title"
        try description.save(dirtyFlags: [.tags])

        let pictures = try flacPictures(in: url)
        #expect(pictures.contains(Picture(type: Self.frontCover, data: try frontData)))
        #expect(pictures.contains(Picture(type: Self.backCover, data: try backData)), "back cover lost; pictures: \(pictures.map(\.type))")

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Saved Title")
    }
}
