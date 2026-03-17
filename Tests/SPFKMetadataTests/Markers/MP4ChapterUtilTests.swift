// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.tags(.file), .serialized)
class MP4ChapterUtilTests: BinTestCase {
    func getChapters(in url: URL) -> [ChapterMarker] {
        let chapters = MP4ChapterUtil.chapters(in: url.path) as? [ChapterMarker] ?? []
        Log.debug(chapters.map { ($0.name ?? "nil") + " @ \($0.startTime)" })
        return chapters
    }

    // MARK: - M4A

    @Test func writeAndReadChaptersM4A() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Intro", startTime: 0, endTime: 1.5),
            ChapterMarker(name: "Verse", startTime: 1.5, endTime: 3),
            ChapterMarker(name: "Outro", startTime: 3, endTime: 4.5),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 3)
        #expect(readBack.map { $0.name } == ["Intro", "Verse", "Outro"])
        #expect(readBack.map { $0.startTime } == [0, 1.5, 3])
    }

    @Test func removeChaptersM4A() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Ch1", startTime: 0, endTime: 1),
            ChapterMarker(name: "Ch2", startTime: 1, endTime: 2),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 2)

        #expect(MP4ChapterUtil.removeChapters(in: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 0)
    }

    @Test func readChaptersFromFileWithNone() async throws {
        // tabla_m4a has no Nero chapters by default
        let chapters = getChapters(in: TestBundleResources.shared.tabla_m4a)
        #expect(chapters.count == 0)
    }

    // MARK: - MP4

    @Test func writeAndReadChaptersMP4() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Part A", startTime: 0.5, endTime: 2),
            ChapterMarker(name: "Part B", startTime: 2, endTime: 3.5),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 2)
        #expect(readBack.map { $0.name } == ["Part A", "Part B"])
        #expect(readBack.map { $0.startTime } == [0.5, 2])
    }

    // MARK: - Timestamp precision

    @Test func timestampPrecision() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Precise", startTime: 3661.123, endTime: 7322.456),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 1)
        #expect(readBack[0].name == "Precise")
        // Verify 100-nanosecond precision round-trip
        #expect(abs(readBack[0].startTime - 3661.123) < 0.001)
    }

    // MARK: - Existing tags preserved

    @Test func existingTagsPreserved() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        // Write some tags first
        var props = try TagProperties(url: tmpfile)
        props[.title] = "Test Title"
        props[.artist] = "Test Artist"
        try props.save(to: tmpfile)

        // Now write chapters
        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Ch1", startTime: 0, endTime: 1),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        // Verify tags are still intact
        let propsAfter = try TagProperties(url: tmpfile)
        #expect(propsAfter[.title] == "Test Title")
        #expect(propsAfter[.artist] == "Test Artist")

        // Verify chapters are there too
        let readBack = getChapters(in: tmpfile)
        #expect(readBack.count == 1)
        #expect(readBack[0].name == "Ch1")
    }

    // MARK: - Overwrite existing chapters

    @Test func overwriteExistingChapters() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        let first: [ChapterMarker] = [
            ChapterMarker(name: "Old1", startTime: 0, endTime: 1),
            ChapterMarker(name: "Old2", startTime: 1, endTime: 2),
        ]

        #expect(MP4ChapterUtil.writeChapters(first, to: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 2)

        let second: [ChapterMarker] = [
            ChapterMarker(name: "New1", startTime: 0, endTime: 0.5),
            ChapterMarker(name: "New2", startTime: 0.5, endTime: 1),
            ChapterMarker(name: "New3", startTime: 1, endTime: 1.5),
        ]

        #expect(MP4ChapterUtil.writeChapters(second, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)
        #expect(readBack.count == 3)
        #expect(readBack.map { $0.name } == ["New1", "New2", "New3"])
    }
}
