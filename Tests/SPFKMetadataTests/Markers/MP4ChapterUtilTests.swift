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

        let sizeBefore = try FileManager.default.attributesOfItem(atPath: tmpfile.path)[.size] as? Int ?? 0

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Intro", startTime: 1, endTime: 2),
            ChapterMarker(name: "Verse", startTime: 2, endTime: 3),
            ChapterMarker(name: "Outro", startTime: 3, endTime: 4),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        let sizeAfter = try FileManager.default.attributesOfItem(atPath: tmpfile.path)[.size] as? Int ?? 0
        Log.debug("File size: before=\(sizeBefore) after=\(sizeAfter) delta=\(sizeAfter - sizeBefore)")

        // File size may shrink if the test file already had a larger chapter track.
        // Just verify the file was modified (size changed).
        #expect(sizeAfter != sizeBefore, "File size should change after writing chapters")

        let readBack = getChapters(in: tmpfile)
        Log.debug("readBack count: \(readBack.count)")

        #expect(readBack.count == 3)
        #expect(readBack.map { $0.name } == ["Intro", "Verse", "Outro"])
        #expect(readBack.map { $0.startTime } == [1, 2, 3])
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
        // Remove any pre-existing chapters, then verify reading returns empty.
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)
        #expect(MP4ChapterUtil.removeChapters(in: tmpfile.path))
        let chapters = getChapters(in: tmpfile)
        #expect(chapters.count == 0)
    }

    // MARK: - MP4

    @Test func writeAndReadChaptersMP4() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        // QT chapter track media timeline starts at 0; first chapter must start at 0.
        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Part A", startTime: 0, endTime: 2),
            ChapterMarker(name: "Part B", startTime: 2, endTime: 3.5),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 2)
        #expect(readBack.map { $0.name } == ["Part A", "Part B"])
        #expect(readBack.map { $0.startTime } == [0, 2])
    }

    // MARK: - Timestamp precision

    @Test func timestampPrecision() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        // First chapter starts at 0 (QT chapter track media timeline constraint).
        // Second chapter at a precise time to verify millisecond round-trip.
        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Start", startTime: 0, endTime: 1.5),
            ChapterMarker(name: "Precise", startTime: 1.5, endTime: 3.0),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 2)
        #expect(readBack[0].name == "Start")
        #expect(readBack[0].startTime == 0)
        #expect(readBack[1].name == "Precise")
        // QT chapter tracks use ms timescale; verify millisecond precision round-trip
        #expect(abs(readBack[1].startTime - 1.5) < 0.002)
        // Last chapter has no successor — endTime is 0
        #expect(readBack[1].endTime == 0)
    }

    @Test func endTimeInferredFromNextChapter() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        // QT chapter track media timeline starts at 0.
        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Ch1", startTime: 0, endTime: 1.0),
            ChapterMarker(name: "Ch2", startTime: 1.0, endTime: 2.5),
            ChapterMarker(name: "Ch3", startTime: 2.5, endTime: 4.0),
        ]

        #expect(MP4ChapterUtil.writeChapters(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)

        #expect(readBack.count == 3)
        #expect(readBack[0].startTime == 0)
        // MP4 infers endTime from next chapter's startTime
        #expect(abs(readBack[0].endTime - 1.0) < 0.001)
        #expect(abs(readBack[1].startTime - 1.0) < 0.001)
        #expect(abs(readBack[1].endTime - 2.5) < 0.001)
        #expect(abs(readBack[2].startTime - 2.5) < 0.001)
        // Last chapter has no successor — endTime is 0
        #expect(readBack[2].endTime == 0)
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
