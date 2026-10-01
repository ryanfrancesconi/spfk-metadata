// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// An MP3 tag save replaces the mapped properties and keeps every ID3v2 frame the PropertyMap
/// can't express: chapters, the table of contents, and other applications' data.
@Suite(.tags(.file))
final class MP3TagSavePreservationTests: BinTestCase {
    private let privateOwner = "com.example.test"
    private let privateData = Data([0x68, 0x69, 0xE9, 0x00, 0xFF, 0x41])

    private func chapters(in url: URL) -> [ChapterMarker] {
        MPEGChapterUtil.read(url.path) as? [ChapterMarker] ?? []
    }

    private func textFrame(_ id: String, _ text: String) -> Data {
        ID3v24TagBuilder.frame(id: id, body: Data([0]) + Data(text.utf8))
    }

    private func txxx(description: String, value: String) -> Data {
        ID3v24TagBuilder.frame(id: "TXXX", body: Data([0]) + Data(description.utf8) + Data([0]) + Data(value.utf8))
    }

    private var privateFrameBody: Data {
        Data(privateOwner.utf8) + Data([0]) + privateData
    }

    /// Latin-1 encoding, MIME type, file name, description, then the object.
    private var generalObjectFrameBody: Data {
        let fields = ["application/octet-stream", "object.bin", "Object"].map { Data($0.utf8) + Data([0]) }
        return Data([0]) + fields.reduce(Data(), +) + Data([0x01, 0x02, 0x03, 0x00, 0xFE])
    }

    /// A 128-byte ID3v1 tag, replacing any the file ends with.
    private func setID3v1(artist: String, in url: URL) throws {
        func field(_ text: String, _ length: Int) -> Data {
            let bytes = Data(text.utf8.prefix(length))
            return bytes + Data(count: length - bytes.count)
        }

        var data = try Data(contentsOf: url)
        if try ID3v2Frames.hasID3v1(in: url) { data.removeLast(128) }

        let fields = [field("", 30), field(artist, 30), field("", 30), field("", 4), field("", 30)]
        data += Data("TAG".utf8) + fields.reduce(Data(), +) + Data([255])

        try data.write(to: url)
    }

    @Test func chaptersSurviveATitleSave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)

        var description = try await MetaAudioFileDescription(parsing: url)
        let markerCount = description.markerCollection.markerDescriptions.count
        try #require(markerCount > 0)

        description.tagProperties[.title] = "Saved Title"
        try description.save(dirtyFlags: [.metadata])

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Saved Title")
        #expect(reread.markerCollection.markerDescriptions.count == markerCount)
    }

    @Test func tableOfContentsSurvivesATagPropertiesSave() throws {
        let url = try copyToBin(url: TestBundleResources.shared.toc_many_children)
        let chapterCount = chapters(in: url).count
        try #require(chapterCount > 0)
        try #require(try ID3v2Frames.frames(in: url).contains { $0.id == "CTOC" })

        try TagProperties(url: url).save(to: url)

        #expect(chapters(in: url).count == chapterCount)
        #expect(try ID3v2Frames.frames(in: url).contains { $0.id == "CTOC" })
    }

    @Test func otherApplicationsFramesSurviveATitleSave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        try ID3v24TagBuilder.replaceTag(in: url, with: [
            ID3v24TagBuilder.tit2(latin1: "Old Title"),
            ID3v24TagBuilder.frame(id: "PRIV", body: privateFrameBody),
            ID3v24TagBuilder.frame(id: "GEOB", body: generalObjectFrameBody),
        ])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Saved Title"
        try description.save(dirtyFlags: [.metadata])

        let frames = try ID3v2Frames.frames(in: url)
        #expect(frames.contains { $0.id == "PRIV" && $0.body == privateFrameBody })
        #expect(frames.contains { $0.id == "GEOB" && $0.body == generalObjectFrameBody })

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Saved Title")
    }

    /// A standard tag and a `TXXX` absent from the saved dictionary are removed, from the ID3v1 tag too.
    @Test func tagsAbsentFromTheDictionaryAreRemoved() throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        try ID3v24TagBuilder.replaceTag(in: url, with: [
            ID3v24TagBuilder.tit2(latin1: "Old Title"),
            textFrame("TPE1", "Old Artist"),
            txxx(description: "SPFK_CUSTOM", value: "custom value"),
        ])
        try setID3v1(artist: "Old Artist", in: url)

        var properties = try TagProperties(url: url)
        try #require(properties[.artist] == "Old Artist")
        try #require(properties.customTags["SPFK_CUSTOM"] == "custom value")

        properties[.artist] = nil
        properties.customTags["SPFK_CUSTOM"] = nil
        properties[.title] = "Saved Title"
        try properties.save(to: url)

        let reread = try TagProperties(url: url)
        #expect(reread[.title] == "Saved Title")
        #expect(reread[.artist] == nil)
        #expect(reread.customTags["SPFK_CUSTOM"] == nil)
    }
}
