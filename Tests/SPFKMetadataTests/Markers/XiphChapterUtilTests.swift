// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.tags(.file), .serialized)
class XiphChapterUtilTests: BinTestCase {
    func getChapters(in url: URL) -> [ChapterMarker] {
        let chapters = XiphChapterUtil.chapters(in: url.path) as? [ChapterMarker] ?? []
        Log.debug(chapters.map { ($0.name ?? "nil") + " @ \($0.startTime)" })
        return chapters
    }

    // MARK: - FLAC

    @Test func writeAndReadChaptersFLAC() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Intro", startTime: 0, endTime: 1.5),
            ChapterMarker(name: "Verse", startTime: 1.5, endTime: 3),
            ChapterMarker(name: "Outro", startTime: 3, endTime: 4.5),
        ]

        #expect(XiphChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 3)
        #expect(readBack.map { $0.name } == ["Intro", "Verse", "Outro"])
        #expect(readBack.map { $0.startTime } == [0, 1.5, 3])
    }

    @Test func removeChaptersFLAC() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Ch1", startTime: 0, endTime: 1),
            ChapterMarker(name: "Ch2", startTime: 1, endTime: 2),
        ]

        #expect(XiphChapterUtil.writeChapters(markers, to: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 2)

        #expect(XiphChapterUtil.removeChapters(in: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 0)
    }

    @Test func readChaptersFLAC() async throws {
        let chapters = getChapters(in: TestBundleResources.shared.tabla_flac)
        #expect(chapters.count == 5)
    }

    // MARK: - OGG Vorbis

    @Test func writeAndReadChaptersOGG() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_ogg)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Part A", startTime: 0.5, endTime: 2),
            ChapterMarker(name: "Part B", startTime: 2, endTime: 3.5),
        ]

        #expect(XiphChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 2)
        #expect(readBack.map { $0.name } == ["Part A", "Part B"])
        #expect(readBack.map { $0.startTime } == [0.5, 2])
    }

    @Test func removeChaptersOGG() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_ogg)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Only", startTime: 0, endTime: 1),
        ]

        #expect(XiphChapterUtil.writeChapters(markers, to: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 1)

        #expect(XiphChapterUtil.removeChapters(in: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 0)
    }

    // MARK: - Timestamp precision

    @Test func timestampPrecision() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Precise", startTime: 3661.123, endTime: 7322.456),
        ]

        #expect(XiphChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 1)
        #expect(readBack[0].name == "Precise")
        // Verify HH:MM:SS.mmm round-trip (01:01:01.123)
        #expect(abs(readBack[0].startTime - 3661.123) < 0.002)
    }
}
