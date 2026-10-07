// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Ratings other tools store where the app never writes: ID3 `TXXX:RATING` with no `POPM`, and Xiph
/// `FMPS_RATING` with no `RATING`. Both are read as stars.
@Suite(.tags(.file))
final class RatingReadFallbackTests: BinTestCase {
    /// A v2.4 `TXXX` in UTF-8.
    private static func userText(_ description: String, _ value: String) -> Data {
        ID3v24TagBuilder.frame(id: "TXXX", body: Data([3]) + Data(description.utf8) + Data([0]) + Data(value.utf8))
    }

    /// Stored as stars, or as the 0–100 scale the Xiph and MP4 writers use.
    static let storedValues: [(stored: String, stars: String)] = [("4", "4"), ("60", "3")]

    @Test(arguments: storedValues.map(\.stored))
    func anMP3RatingInTXXXIsRead(stored: String) async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try ID3v24TagBuilder.replaceTag(in: url, with: [ID3v24TagBuilder.tit2("Rated"), Self.userText("RATING", stored)])

        let description = try await MetaAudioFileDescription(parsing: url)
        let expected = Self.storedValues.first { $0.stored == stored }?.stars

        #expect(description.tagProperties[.rating] == expected)
    }

    @Test(arguments: storedValues.map(\.stored))
    func aWAVRatingInTXXXIsRead(stored: String) async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try ID3v24TagBuilder.replaceWAVTag(in: url, with: [ID3v24TagBuilder.tit2("Rated"), Self.userText("RATING", stored)])

        let description = try await MetaAudioFileDescription(parsing: url)
        let expected = Self.storedValues.first { $0.stored == stored }?.stars

        #expect(description.tagProperties[.rating] == expected)
    }

    /// FMPS stores 0.0–1.0; 0.6 is three stars.
    @Test func aFLACRatingInFMPSRatingAloneIsRead() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        try FLACBlockWriter.rewrite(url) { blocks in
            guard let index = blocks.firstIndex(where: { $0.blockType == .vorbisComment }) else { throw FLACBlocks.ReadError.malformed("no comment") }
            let comment = try VorbisComment(blocks[index].payload)
            let fields = comment.fields.filter { !["RATING", "FMPS_RATING"].contains($0.key.uppercased()) }
                + [VorbisComment.Field(key: "FMPS_RATING", value: "0.6")]
            blocks[index] = FLACBlockWriter.vorbisComment(vendor: comment.vendor, fields: fields)
        }

        let description = try await MetaAudioFileDescription(parsing: url)

        #expect(description.tagProperties[.rating] == "3")
    }
}
