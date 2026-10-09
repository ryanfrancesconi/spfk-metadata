// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import ImageIO
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// The artwork is the file's front cover wherever it sits among the pictures, and a save keeps it.
@Suite(.tags(.file))
final class FrontCoverSelectionTests: BinTestCase {
    private struct PixelSize: Equatable {
        let width: Int
        let height: Int
    }

    private static let frontCover: UInt8 = 3
    private static let backCover: UInt8 = 4

    /// sharksandwich.jpg is 425 x 425, songbird.jpg 1600 x 900 (`sips -g pixelWidth -g pixelHeight`).
    private static let frontSize = PixelSize(width: 425, height: 425)
    private static let backSize = PixelSize(width: 1600, height: 900)

    private func apic(type: UInt8, description: String, image: URL) throws -> Data {
        let body = try Data([0]) + Data("image/jpeg".utf8) + Data([0, type]) + Data(description.utf8) + Data([0]) + Data(contentsOf: image)
        return ID3v24TagBuilder.frame(id: "APIC", body: body)
    }

    /// The back cover first, then the front cover.
    private func frames() throws -> [Data] {
        try [
            ID3v24TagBuilder.tit2(latin1: "Title"),
            apic(type: Self.backCover, description: "Back", image: TestBundleResources.shared.songbird),
            apic(type: Self.frontCover, description: "Front", image: TestBundleResources.shared.sharksandwich),
        ]
    }

    private func pixelSize(_ data: Data) -> PixelSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return PixelSize(width: image.width, height: image.height)
    }

    private func pixelSize(of description: MetaAudioFileDescription) -> PixelSize? {
        guard let image = description.imageDescription.pictureRef?.cgImage else { return nil }
        return PixelSize(width: image.width, height: image.height)
    }

    /// Picture type to pixel size, for every `APIC` in `tag`.
    private func pictures(in tag: ID3v2Frames.Tag) throws -> [(type: UInt8, size: PixelSize?)] {
        try tag.frames("APIC").map {
            let picture = try ID3v2Frames.Picture($0.body)
            return (picture.pictureType, pixelSize(picture.data))
        }
    }

    private func wavTag(in url: URL) throws -> ID3v2Frames.Tag {
        let payload = try IFFChunks.payload(id: "ID3 ", in: url, bigEndian: false)
            ?? IFFChunks.payload(id: "id3 ", in: url, bigEndian: false)
        let data = try #require(payload)
        return try #require(try ID3v2Frames.tag(in: data))
    }

    /// Parse, then save `[.tags, .image]` with no edit, then the tag's pictures.
    private func parseAndSave(_ url: URL, tag: (URL) throws -> ID3v2Frames.Tag) async throws -> [(type: UInt8, size: PixelSize?)] {
        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(pixelSize(of: description) == Self.frontSize, "artwork is not the front cover")

        try description.save(dirtyFlags: [.tags, .image])
        return try pictures(in: tag(url))
    }

    private func expectKept(_ pictures: [(type: UInt8, size: PixelSize?)]) {
        let front = pictures.filter { $0.type == Self.frontCover }.map(\.size)
        #expect(front == [Self.frontSize], "front cover pixel sizes after save: \(front)")

        #expect(pictures.contains { $0.type == Self.backCover && $0.size == Self.backSize })
    }

    // MARK: - MP3

    @Test func mp3ArtworkIsTheFrontCoverAndASaveKeepsIt() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        try ID3v24TagBuilder.replaceTag(in: url, with: frames())

        let pictures = try await parseAndSave(url) { try #require(try ID3v2Frames.tag(in: $0)) }
        expectKept(pictures)
    }

    // MARK: - WAV

    @Test func wavArtworkIsTheFrontCoverAndASaveKeepsIt() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try ID3v24TagBuilder.replaceWAVTag(in: url, with: frames())

        let pictures = try await parseAndSave(url, tag: wavTag(in:))
        expectKept(pictures)
    }
}
