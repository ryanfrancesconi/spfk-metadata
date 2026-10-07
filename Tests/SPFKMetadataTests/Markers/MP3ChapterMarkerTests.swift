// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.tags(.file))
class MP3ChapterMarkerTests: BinTestCase {
    func getChapters(in url: URL) -> [ChapterMarker] {
        let chapters = MPEGChapterUtil.read(url.path) as? [ChapterMarker] ?? []
        return chapters
    }

    @Test func parseMarkers() async throws {
        let markers = getChapters(in: TestBundleResources.shared.mp3_id3)

        let names = markers.compactMap { $0.name }
        let times = markers.map { $0.startTime }

        #expect(markers.count == 3)
        #expect(names == ["M0", "M1", "M2"])
        #expect(times == [0.0, 1, 2])
    }

    @Test func parseMarkers2() async throws {
        let markers = getChapters(in: TestBundleResources.shared.toc_many_children)
        #expect(markers.count == 129)
    }

    @Test func writeMarkers() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        #expect(MPEGChapterUtil.remove(tmpfile.path))

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "New 1", startTime: 2, endTime: 4),
            ChapterMarker(name: "New 2", startTime: 4, endTime: 6),
        ]

        #expect(MPEGChapterUtil.write(markers, to: tmpfile.path))

        let editedMarkers = getChapters(in: tmpfile)

        let names = editedMarkers.compactMap { $0.name }
        let times = editedMarkers.map { $0.startTime }

        #expect(editedMarkers.count == 2)
        #expect(names == ["New 1", "New 2"])
        #expect(times == [2, 4])
    }

    @Test func removeMarkers() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        #expect(MPEGChapterUtil.remove(tmpfile.path))

        let chapters = getChapters(in: tmpfile)
        #expect(chapters.count == 0)
    }

    @Test func timestampPrecision() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        #expect(MPEGChapterUtil.remove(tmpfile.path))

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Precise", startTime: 3661.123, endTime: 7322.456),
        ]

        #expect(MPEGChapterUtil.write(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 1)
        #expect(readBack[0].name == "Precise")
        // ID3v2 CHAP frames store time in milliseconds
        #expect(abs(readBack[0].startTime - 3661.123) < 0.002)
        #expect(abs(readBack[0].endTime - 7322.456) < 0.002)
    }

    @Test func colorRoundTripMP3() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        #expect(MPEGChapterUtil.remove(tmpfile.path))

        let hex = HexColor(string: "0000FFFF")!
        let desc = AudioMarkerDescription(name: "Blue Cue", startTime: 1.0, hexColor: hex)
        #expect(MPEGChapterUtil.write([desc.colorEncodedChapterMarker], to: tmpfile.path))

        let collection = try await AudioMarkerDescriptionCollection(url: tmpfile)
        #expect(collection.markerDescriptions.count == 1)
        #expect(collection.markerDescriptions[0].name == "Blue Cue")
        #expect(collection.markerDescriptions[0].hexColor?.stringValue == "0000FFFF")
    }

    /// A non-text frame embedded in a CHAP must not stop the TIT2 naming it, in either order.
    @Test(arguments: [false, true])
    func chapterWithEmbeddedURLFrame(urlFrameFirst: Bool) async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        let tit2 = ID3v24TagBuilder.tit2("Intro")
        let wxxx = ID3v24TagBuilder.wxxx(description: "", url: "https://example.com")
        let chap = ID3v24TagBuilder.chap(
            elementID: "ch0",
            startMs: 1500,
            endMs: 2500,
            embedded: urlFrameFirst ? [wxxx, tit2] : [tit2, wxxx]
        )
        try ID3v24TagBuilder.replaceTag(in: tmpfile, with: [chap])

        let chapters = getChapters(in: tmpfile)

        #expect(chapters.count == 1)
        #expect(chapters.first?.name == "Intro")
        #expect(chapters.first?.startTime == 1.5)
    }

    /// A `CHAP` frame TagLib cannot decode is skipped; the chapters beside it still read.
    @Test(arguments: [
        ID3v24TagBuilder.compressedChap(elementID: "packed", startMs: 0, endMs: 1000),
        ID3v24TagBuilder.encryptedChap(elementID: "sealed", startMs: 0, endMs: 1000),
    ])
    func undecodableChapterFrameIsSkipped(undecodable: Data) async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let readable = ID3v24TagBuilder.chap(
            elementID: "ch1",
            startMs: 1000,
            endMs: 2000,
            embedded: [ID3v24TagBuilder.tit2("Readable")]
        )
        try ID3v24TagBuilder.replaceTag(in: tmpfile, with: [undecodable, readable])

        let chapters = getChapters(in: tmpfile)

        #expect(chapters.map(\.name) == ["Readable"])
        #expect(chapters.map(\.startTime) == [1])
    }

    /// Each title is how some writer stores it: another tool's UTF-16, genuine Latin-1, and the
    /// UTF-8 bytes in a Latin-1 frame this package wrote before titles were written as UTF-8.
    @Test(arguments: [
        (ID3v24TagBuilder.tit2(utf16: "日本語"), "日本語"),
        (ID3v24TagBuilder.tit2(latin1: "Café"), "Café"),
        (ID3v24TagBuilder.tit2("日本語"), "日本語"),
        (ID3v24TagBuilder.tit2("Café"), "Café"),
    ])
    func nonASCIIChapterTitleReads(tit2: Data, expected: String) async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let chap = ID3v24TagBuilder.chap(elementID: "ch0", startMs: 0, endMs: 1000, embedded: [tit2])
        try ID3v24TagBuilder.replaceTag(in: tmpfile, with: [chap])

        #expect(getChapters(in: tmpfile).first?.name == expected)
    }

    @Test func nonASCIIChapterTitleIsWrittenAsUTF8() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let title = "日本語 Café"

        #expect(MPEGChapterUtil.write([ChapterMarker(name: title, startTime: 0, endTime: 1)], to: tmpfile.path))

        let bytes = try Data(contentsOf: tmpfile)
        #expect(bytes.range(of: Data([3]) + Data(title.utf8)) != nil)
        #expect(getChapters(in: tmpfile).first?.name == title)
    }

    /// A chapter with no TIT2 is named by its element ID: UTF-8 from most writers, Latin-1 from some.
    @Test(arguments: [
        (Data("日本語".utf8), "日本語"),
        (Data("Café".utf8), "Café"),
        ("Café".data(using: .isoLatin1) ?? Data(), "Café"),
    ])
    func nonASCIIElementIDNamesUntitledChapter(elementID: Data, expected: String) async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let chap = ID3v24TagBuilder.chap(elementID: elementID, startMs: 0, endMs: 1000, embedded: [])
        try ID3v24TagBuilder.replaceTag(in: tmpfile, with: [chap])

        #expect(getChapters(in: tmpfile).first?.name == expected)
    }

    /// Element IDs are numbered, so chapters sharing a name stay distinct, and the one table of
    /// contents lists them in order; the name, non-ASCII included, is each chapter's TIT2.
    @Test func chaptersSharingANameGetDistinctIDsListedInTheTableOfContents() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let name = "日本語 Café"

        #expect(MPEGChapterUtil.write([
            ChapterMarker(name: name, startTime: 0, endTime: 1),
            ChapterMarker(name: name, startTime: 1, endTime: 2),
        ], to: tmpfile.path))

        let tag = try #require(try ID3v2Frames.tag(in: tmpfile))
        let chapters = try tag.frames("CHAP").map { try ID3v2Frames.Chapter($0.body, majorVersion: tag.majorVersion) }
        let tables = try tag.frames("CTOC").map { try ID3v2Frames.TableOfContents($0.body, majorVersion: tag.majorVersion) }

        #expect(chapters.map(\.elementID) == ["chp0", "chp1"])
        #expect(tables.count == 1)
        #expect(tables.first?.children == ["chp0", "chp1"])
        #expect(tables.first?.isTopLevel == true)
        #expect(tables.first?.isOrdered == true)
        #expect(getChapters(in: tmpfile).map(\.name) == [name, name])
    }

    @Test func removingEveryChapterRemovesTheTableOfContents() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        #expect(MPEGChapterUtil.write([ChapterMarker(name: "One", startTime: 0, endTime: 1)], to: tmpfile.path))
        #expect(MPEGChapterUtil.write([], to: tmpfile.path))

        let tag = try ID3v2Frames.tag(in: tmpfile)
        #expect(tag?.frames("CTOC").isEmpty ?? true)
        #expect(tag?.frames("CHAP").isEmpty ?? true)
    }

    @Test func endTimeRoundTrip() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        #expect(MPEGChapterUtil.remove(tmpfile.path))

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Ch1", startTime: 0.5, endTime: 1.5),
            ChapterMarker(name: "Ch2", startTime: 1.5, endTime: 3.0),
        ]

        #expect(MPEGChapterUtil.write(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 2)
        #expect(abs(readBack[0].startTime - 0.5) < 0.002)
        #expect(abs(readBack[0].endTime - 1.5) < 0.002)
        #expect(abs(readBack[1].startTime - 1.5) < 0.002)
        #expect(abs(readBack[1].endTime - 3.0) < 0.002)
    }
}
