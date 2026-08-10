// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.tags(.file))
class MP4ChapterUtilTests: BinTestCase {
    func getChapters(in url: URL) -> [ChapterMarker] {
        let chapters = MP4ChapterUtil.read(url.path) as? [ChapterMarker] ?? []
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

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

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

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 2)

        #expect(MP4ChapterUtil.remove(tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 0)
    }

    @Test func readChaptersFromFileWithNone() async throws {
        // Remove any pre-existing chapters, then verify reading returns empty.
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)
        #expect(MP4ChapterUtil.remove(tmpfile.path))
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

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

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

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

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

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

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

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

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

        #expect(MP4ChapterUtil.write(first, to: tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 2)

        let second: [ChapterMarker] = [
            ChapterMarker(name: "New1", startTime: 0, endTime: 0.5),
            ChapterMarker(name: "New2", startTime: 0.5, endTime: 1),
            ChapterMarker(name: "New3", startTime: 1, endTime: 1.5),
        ]

        #expect(MP4ChapterUtil.write(second, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)
        #expect(readBack.count == 3)
        #expect(readBack.map { $0.name } == ["New1", "New2", "New3"])
    }

    // MARK: - Remove from file with no chapters always succeeds

    @Test func removeFromFileWithNoChapters() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        // Ensure no chapters are present
        #expect(MP4ChapterUtil.remove(tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 0)

        // Calling remove again on a file with no chapters should still succeed gracefully
        #expect(MP4ChapterUtil.remove(tmpfile.path))
        #expect(getChapters(in: tmpfile).count == 0)
    }

    // MARK: - Error handling: missing or wrong-type file

    @Test func chaptersInNilForMissingFile() async throws {
        let missing = "/tmp/this-file-does-not-exist-\(UUID().uuidString).m4a"
        let chapters = MP4ChapterUtil.read(missing) as? [ChapterMarker] ?? []
        #expect(chapters.isEmpty, "Should return nil/empty for non-existent file")
    }

    @Test func writeChaptersFalseForMissingFile() async throws {
        let missing = "/tmp/this-file-does-not-exist-\(UUID().uuidString).m4a"
        let markers: [ChapterMarker] = [ChapterMarker(name: "Ch", startTime: 0, endTime: 1)]
        #expect(!MP4ChapterUtil.write(markers, to: missing),
                "Should return false when file does not exist")
    }

    @Test func chaptersInNilForNonMP4File() async throws {
        // WAV file is not an MP4 container — should return empty gracefully
        let chapters = MP4ChapterUtil.read(TestBundleResources.shared.tabla_wav.path)
            as? [ChapterMarker] ?? []
        #expect(chapters.isEmpty, "Should return nil/empty for non-MP4 file")
    }

    // MARK: - Unicode titles round-trip

    @Test func unicodeTitleRoundTrip() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "第一章", startTime: 0, endTime: 1),
            ChapterMarker(name: "🎵 Beat Drop", startTime: 1, endTime: 2),
            ChapterMarker(name: "Ünïcödé", startTime: 2, endTime: 3),
        ]

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

        let readBack = getChapters(in: tmpfile)
        #expect(readBack.count == 3)
        #expect(readBack[0].name == "第一章")
        #expect(readBack[1].name == "🎵 Beat Drop")
        #expect(readBack[2].name == "Ünïcödé")
    }

    // MARK: - No orphaned mdat atoms after repeated write/remove cycles
    //
    // Regression test for PR #1325 / commit 7b7b5ebd:
    // Before the fix, each add/remove cycle appended a chapter mdat without
    // removing it during chapter track removal. File size must stabilize.

    @Test func noOrphanedMdatRegressionTest() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "Ch1", startTime: 0, endTime: 1),
            ChapterMarker(name: "Ch2", startTime: 1, endTime: 2),
        ]

        // Establish a clean baseline with no chapters
        #expect(MP4ChapterUtil.remove(tmpfile.path))

        // Three write/remove cycles — file size after each remove must be stable
        var lastRemoveSize: Int = 0

        for cycle in 0 ..< 3 {
            #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))
            #expect(MP4ChapterUtil.remove(tmpfile.path))

            let removeSize = try FileManager.default.attributesOfItem(atPath: tmpfile.path)[.size] as? Int ?? 0

            if cycle > 0 {
                #expect(
                    removeSize == lastRemoveSize,
                    "File grew by \(removeSize - lastRemoveSize) bytes after remove #\(cycle + 1): orphaned mdat regression"
                )
            }
            lastRemoveSize = removeSize
        }
    }

    // MARK: - Video

    /// **Writing chapters must not cost the file its other tracks.** A video file reaches this
    /// writer through the same path an m4a does — ShadowTag clamps region markers into a trimmed
    /// video, and the result replaces the user's original. A track dropped here is silent data
    /// loss: the write reports success and the caller has no reason to look.
    @Test func writingChaptersToAVideoKeepsItsAudioTrack() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.sample_mov)

        let before = try await AVURLAsset(url: tmpfile).load(.tracks)
        let audioBefore = before.filter { $0.mediaType == .audio }
        let videoBefore = before.filter { $0.mediaType == .video }

        #expect(audioBefore.count == 1, "fixture must start with an audio track")
        #expect(videoBefore.count == 1, "fixture must start with a video track")

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "One", startTime: 0, endTime: 0.5),
            ChapterMarker(name: "Two", startTime: 0.5, endTime: 1),
            ChapterMarker(name: "Three", startTime: 1, endTime: 1.5),
            ChapterMarker(name: "Four", startTime: 1.5, endTime: 2),
        ]

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

        let after = try await AVURLAsset(url: tmpfile).load(.tracks)

        #expect(after.filter { $0.mediaType == .audio }.count == 1, "audio track lost")
        #expect(after.filter { $0.mediaType == .video }.count == 1, "video track lost")
    }

    /// **A chapter past the end of the file must not cost the file its audio.** After a trim, the
    /// in-memory markers still carry pre-trim times, so `saveMarkers()` writes start times beyond
    /// the shortened duration. TagLib links its chapter track to the first audio track via
    /// `tref/chap`, so anything that confuses the builder lands on the audio.
    @Test func writingAChapterPastTheEndKeepsTheAudioTrack() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.sample_mov)

        let duration = try await AVURLAsset(url: tmpfile).load(.duration).seconds
        let framesBefore = try AVAudioFile(forReading: tmpfile).length

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "InRange", startTime: 0.5, endTime: 1),
            ChapterMarker(name: "PastEnd", startTime: duration + 4, endTime: duration + 5),
        ]

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

        let tracks = try await AVURLAsset(url: tmpfile).load(.tracks)
        #expect(tracks.filter { $0.mediaType == .audio }.count == 1, "audio track lost")

        let framesAfter = (try? AVAudioFile(forReading: tmpfile))?.length ?? 0
        #expect(framesAfter == framesBefore, "audio frames went \(framesBefore) → \(framesAfter)")
    }

    /// The audio must still decode, not merely be listed. `isAVPlayable` is derived from this exact
    /// measurement, and it is what decides whether the file can be edited again at all.
    @Test func writingChaptersToAVideoLeavesTheAudioReadable() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.sample_mov)

        let framesBefore = try AVAudioFile(forReading: tmpfile).length
        #expect(framesBefore > 0, "fixture must start with readable audio")

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "One", startTime: 0, endTime: 1),
            ChapterMarker(name: "Two", startTime: 1, endTime: 2),
        ]

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

        let framesAfter = (try? AVAudioFile(forReading: tmpfile))?.length ?? 0
        #expect(framesAfter == framesBefore, "audio frame count went \(framesBefore) → \(framesAfter)")
    }

    // MARK: - Chapter reference on a track that already has one

    /// A `trak` carries at most one `tref`, so the chapter reference has to join the atom already
    /// there rather than bring a second one. AVFoundation drops a track carrying two, which costs
    /// the file its audio while `ffprobe` and TagLib still read it back perfectly.
    @Test func writingChaptersKeepsAudioWhenTheAudioTrackAlreadyHasATref() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.sample_timecode_mov)

        let framesBefore = try AVAudioFile(forReading: tmpfile).length
        #expect(framesBefore > 0, "fixture must start with readable audio")

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "One", startTime: 0, endTime: 1),
            ChapterMarker(name: "Two", startTime: 1, endTime: 2),
        ]

        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))

        let framesAfter = (try? AVAudioFile(forReading: tmpfile))?.length ?? 0
        #expect(framesAfter == framesBefore, "audio frame count went \(framesBefore) → \(framesAfter)")
    }

    /// The merge is structural, so it is asserted structurally: one `tref`, both references in it,
    /// and removal taking only `chap` back out. A frame count cannot see the timecode reference,
    /// which a removal that deletes the whole atom would take with it.
    @Test func chapterReferenceSharesTheAudioTracksTref() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.sample_timecode_mov)

        #expect(try audioTrackTrefs(in: tmpfile) == [["tmcd"]])

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "One", startTime: 0, endTime: 1),
        ]
        #expect(MP4ChapterUtil.write(markers, to: tmpfile.path))
        #expect(try audioTrackTrefs(in: tmpfile) == [["tmcd", "chap"]])

        #expect(MP4ChapterUtil.remove(tmpfile.path))
        #expect(try audioTrackTrefs(in: tmpfile) == [["tmcd"]])
    }

    // MARK: - Atom inspection

    /// The reference types inside each `tref` of the file's first audio `trak`, in file order.
    ///
    /// Grouped per `tref` rather than flattened, so a track carrying two of them is distinguishable
    /// from one carrying a single merged atom — which is the whole distinction under test.
    private func audioTrackTrefs(in url: URL) throws -> [[String]] {
        let data = try Data(contentsOf: url)

        func children(of range: Range<Int>) -> [(type: String, body: Range<Int>)] {
            var result: [(String, Range<Int>)] = []
            var pos = range.lowerBound

            while pos + 8 <= range.upperBound {
                var size = Int(data.beUInt32(at: pos))
                var header = 8

                if size == 1 {
                    size = Int(data.beUInt64(at: pos + 8))
                    header = 16
                } else if size == 0 {
                    size = range.upperBound - pos
                }
                guard size >= header, pos + size <= range.upperBound else { break }

                result.append((data.fourCC(at: pos + 4), (pos + header) ..< (pos + size)))
                pos += size
            }
            return result
        }

        func find(_ type: String, in range: Range<Int>) -> Range<Int>? {
            children(of: range).first { $0.type == type }?.body
        }

        guard let moov = find("moov", in: 0 ..< data.count) else { return [] }

        for trak in children(of: moov).filter({ $0.type == "trak" }) {
            guard let mdia = find("mdia", in: trak.body),
                  let hdlr = find("hdlr", in: mdia),
                  // handler_type follows version/flags and 4 reserved bytes
                  data.fourCC(at: hdlr.lowerBound + 8) == "soun" else { continue }

            return children(of: trak.body)
                .filter { $0.type == "tref" }
                .map { children(of: $0.body).map(\.type) }
        }
        return []
    }
}

private extension Data {
    func beUInt32(at offset: Int) -> UInt32 {
        self[offset ..< offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
    }

    func beUInt64(at offset: Int) -> UInt64 {
        self[offset ..< offset + 8].reduce(0) { $0 << 8 | UInt64($1) }
    }

    func fourCC(at offset: Int) -> String {
        String(decoding: self[offset ..< offset + 4], as: UTF8.self)
    }
}
