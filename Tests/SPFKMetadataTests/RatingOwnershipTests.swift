// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// The app writes its rating to its own `POPM` frame only. Other players' frames, ratings and play
/// counts survive every save, and a rating the user clears reads as cleared rather than as another
/// player's.
@Suite(.tags(.file))
final class RatingOwnershipTests: BinTestCase {
    static let otherEmail = "player@example.com"
    static let appEmail = "Windows Media Player 9 Series"

    private func popularimeters(inMP3 url: URL) throws -> [ID3v2Frames.Popularimeter] {
        try #require(try ID3v2Frames.tag(in: url)).frames("POPM").map { try ID3v2Frames.Popularimeter($0.body) }
    }

    private func popularimeters(inWAV url: URL) throws -> [ID3v2Frames.Popularimeter] {
        let chunk = try #require(try RIFFChunks(contentsOf: url).first("ID3 "))
        return try #require(try ID3v2Frames.tag(in: chunk.payload)).frames("POPM").map { try ID3v2Frames.Popularimeter($0.body) }
    }

    /// 196 is four stars on the range most players share.
    @Test func clearingAnMP3RatingKeepsAnotherPlayersFrameAndReadsUnrated() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try ID3v24TagBuilder.replaceTagWithVersion3(in: url, frames: [
            ID3v24TagBuilder.version3Popularimeter(email: Self.otherEmail, rating: 196, counter: 7),
        ])

        var description = try await MetaAudioFileDescription(parsing: url)
        try #require(description.tagProperties[.rating] == "4")

        description.tagProperties.set(tag: .rating, value: nil)
        try description.save(dirtyFlags: [.tags])

        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.rating] == nil)

        let other = try popularimeters(inMP3: url).filter { $0.email == Self.otherEmail }
        #expect(other.map(\.rating) == [196])
        #expect(other.map(\.counter) == [7])
    }

    /// A play count with no rating reads as unrated, so a save has nothing to override and adds no
    /// frame of its own.
    @Test func anMP3TagSaveKeepsAnotherPlayersPlayCountAndAddsNoFrame() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try ID3v24TagBuilder.replaceTagWithVersion3(in: url, frames: [
            ID3v24TagBuilder.version3Popularimeter(email: Self.otherEmail, rating: 0, counter: 42),
        ])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Edited")
        try description.save(dirtyFlags: [.tags])

        let frames = try popularimeters(inMP3: url)
        #expect(frames.map(\.email) == [Self.otherEmail])
        #expect(frames.first?.counter == 42)
    }

    @Test func clearingAWAVRatingKeepsAnotherPlayersFrameAndReadsUnrated() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let popm = ID3v24TagBuilder.frame(
            id: "POPM", body: Data(Self.otherEmail.utf8) + Data([0, 196]) + ID3v24TagBuilder.bigEndian(7)
        )
        try ID3v24TagBuilder.replaceWAVTag(in: url, with: [popm])

        var description = try await MetaAudioFileDescription(parsing: url)
        try #require(description.tagProperties[.rating] == "4")

        description.tagProperties.set(tag: .rating, value: nil)
        try description.save(dirtyFlags: [.tags])

        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.rating] == nil)

        let other = try popularimeters(inWAV: url).filter { $0.email == Self.otherEmail }
        #expect(other.map(\.rating) == [196])
        #expect(other.map(\.counter) == [7])
    }

    /// The app's own rating sits beside another player's and is the one read back.
    @Test func ratingAnMP3KeepsAnotherPlayersFrame() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try ID3v24TagBuilder.replaceTagWithVersion3(in: url, frames: [
            ID3v24TagBuilder.version3Popularimeter(email: Self.otherEmail, rating: 196, counter: 7),
        ])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.rating] = "2"
        try description.save(dirtyFlags: [.tags])

        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.rating] == "2")
        #expect(Set(try popularimeters(inMP3: url).map(\.email)) == [Self.otherEmail, Self.appEmail])
    }
}
