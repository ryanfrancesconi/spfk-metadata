// Copyright Ryan Francesconi. All Rights Reserved.

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// A file already holding more markers than its format's ``MarkerStorage/maximumMarkerCount`` keeps
/// every one through a marker save and a tag save.
@Suite(.tags(.file))
final class MarkerOverLimitSaveTests: BinTestCase {
    private func chapters(_ count: Int, duration: TimeInterval) -> [ChapterMarker] {
        let spacing = duration / Double(count + 1)
        return (0 ..< count).map {
            let start = spacing * Double($0 + 1)
            return ChapterMarker(name: "C\($0 + 1)", startTime: start, endTime: start)
        }
    }

    private func renameFirstAndSave(_ url: URL) async throws {
        var description = try await MetaAudioFileDescription(parsing: url)
        var markers = description.markerCollection.markerDescriptions.sorted()
        try #require(markers.isNotEmpty)
        markers[0].name = "Renamed"
        description.markerCollection.update(markerDescriptions: markers)
        try description.save(dirtyFlags: [.markers])
    }

    private func retitleAndSave(_ url: URL) async throws {
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Retitled"
        try description.save(dirtyFlags: [.tags])
    }

    private func markerCount(_ url: URL) async throws -> Int {
        try await MetaAudioFileDescription(parsing: url).markerCollection.markerDescriptions.count
    }

    private func avFoundationChapterCount(_ url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let locales = try await asset.load(.availableChapterLocales)
        return try await asset.loadChapterMetadataGroups(
            bestMatchingPreferredLanguages: locales.map(\.identifier) + ["und"]
        ).count
    }

    // MARK: - Xiph

    /// `CHAPTER000` to `CHAPTER999` from our writer, then four-digit keys appended raw, as another
    /// tool writes them.
    private func overLimitFLAC() async throws -> (URL, Int) {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        let limit = try #require(AudioFileType.flac.markerStorage?.maximumMarkerCount)
        let count = limit + 200
        let duration = try #require(try await MetaAudioFileDescription(parsing: url).audioFormat?.duration)
        let all = chapters(count, duration: duration)
        try #require(XiphChapterUtil.write(Array(all.prefix(limit)), to: url.path))

        let extra = all.enumerated().dropFirst(limit).flatMap { index, chapter in
            ["CHAPTER\(index)=\(Self.timestamp(chapter.startTime))", "CHAPTER\(index)NAME=C\(index + 1)"]
        }
        try Self.appendVorbisComments(extra, toFLAC: url)
        return (url, count)
    }

    private static func timestamp(_ seconds: TimeInterval) -> String {
        let ms = Int((seconds * 1000).rounded())
        return String(format: "%02d:%02d:%02d.%03d", ms / 3_600_000, ms / 60000 % 60, ms / 1000 % 60, ms % 1000)
    }

    /// Appends `fields` to the FLAC's VORBIS_COMMENT block, rewriting the file.
    private static func appendVorbisComments(_ fields: [String], toFLAC url: URL) throws {
        var data = try Data(contentsOf: url)
        try #require(data.prefix(4) == Data("fLaC".utf8))

        func uint32LE(_ at: Int) -> Int {
            (0 ..< 4).reduce(0) { $0 | Int(data[data.startIndex + at + $1]) << (8 * $1) }
        }
        func le32(_ value: Int) -> Data {
            Data((0 ..< 4).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
        }

        var offset = 4
        while true {
            let header = data[offset]
            let length = Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])

            if header & 0x7F == 4 {
                let body = offset + 4
                let vendorLength = uint32LE(body)
                let countAt = body + 4 + vendorLength
                var block = data.subdata(in: body ..< body + length)
                let newCount = uint32LE(countAt) + fields.count
                block.replaceSubrange(countAt - body ..< countAt - body + 4, with: le32(newCount))
                for field in fields {
                    let bytes = Data(field.utf8)
                    block.append(le32(bytes.count) + bytes)
                }
                try #require(block.count < 1 << 24)

                let newHeader = Data([header, UInt8(block.count >> 16 & 0xFF), UInt8(block.count >> 8 & 0xFF), UInt8(block.count & 0xFF)])
                data.replaceSubrange(offset ..< body + length, with: newHeader + block)
                try data.write(to: url)
                return
            }

            try #require(header & 0x80 == 0, "no VORBIS_COMMENT block")
            offset += 4 + length
        }
    }

    @Test func xiphParseReadsEveryChapterOverTheLimit() async throws {
        let (url, count) = try await overLimitFLAC()
        #expect(try await markerCount(url) == count)
    }

    /// Rewriting past `CHAPTER999` would need a fourth digit, which readers take as an earlier chapter.
    @Test func xiphMarkerSaveRefusesOverTheLimitAndKeepsEveryChapter() async throws {
        let (url, count) = try await overLimitFLAC()

        let error = await #expect(throws: MetadataError.self) {
            try await self.renameFirstAndSave(url)
        }
        guard case let .incompleteSave(_, failures) = error else {
            Issue.record("expected incompleteSave, got \(String(describing: error))")
            return
        }
        #expect(failures.contains { if case .writeFailed(.markers, _) = $0 { true } else { false } })

        let data = try Data(contentsOf: url)
        #expect(data.range(of: Data("CHAPTER\(count - 1)=".utf8)) != nil)
        #expect(data.range(of: Data("Renamed".utf8)) == nil)
        #expect(try await markerCount(url) == count)
    }

    @Test func xiphTagSaveKeepsEveryChapterOverTheLimit() async throws {
        let (url, count) = try await overLimitFLAC()
        try await retitleAndSave(url)

        let data = try Data(contentsOf: url)
        #expect(data.range(of: Data("CHAPTER\(count - 1)=".utf8)) != nil)
        #expect(data.range(of: Data("CHAPTER\(count - 1)NAME=C\(count)".utf8)) != nil)
    }

    // MARK: - ID3

    private func overLimitMP3() async throws -> (URL, Int) {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let limit = try #require(AudioFileType.mp3.markerStorage?.maximumMarkerCount)
        let count = limit + 45
        let duration = try #require(try await MetaAudioFileDescription(parsing: url).audioFormat?.duration)
        try #require(MPEGChapterUtil.write(chapters(count, duration: duration), to: url.path))
        return (url, count)
    }

    @Test func id3MarkerSaveKeepsEveryChapterOverTheLimit() async throws {
        let (url, count) = try await overLimitMP3()
        try await renameFirstAndSave(url)

        #expect(try await markerCount(url) == count)
    }

    @Test func id3TagSaveKeepsEveryChapterOverTheLimit() async throws {
        let (url, count) = try await overLimitMP3()
        try await retitleAndSave(url)

        #expect(try await markerCount(url) == count)
    }

    /// AVFoundation lists only the top-level `CTOC`'s children, so a wrapped count hides chapters.
    @Test func id3OverLimitTableOfContentsListsTheLimit() async throws {
        let (url, _) = try await overLimitMP3()
        let limit = try #require(AudioFileType.mp3.markerStorage?.maximumMarkerCount)

        #expect(try await avFoundationChapterCount(url) == limit)
    }

    // MARK: - AIFF

    @Test func aiffMarkerSaveKeepsEveryMarkerOverTheLimit() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        let limit = try #require(AudioFileType.aiff.markerStorage?.maximumMarkerCount)
        let count = limit + 1000

        var description = try await MetaAudioFileDescription(parsing: url)
        let duration = try #require(description.audioFormat?.duration)
        let spacing = duration / Double(count + 1)
        description.markerCollection.update(markerDescriptions: (0 ..< count).map {
            AudioMarkerDescription(name: "M\($0 + 1)", startTime: spacing * Double($0 + 1))
        })
        try description.save(dirtyFlags: [.markers])
        try #require(try await markerCount(url) == count)

        try await renameFirstAndSave(url)

        #expect(try await markerCount(url) == count)
    }
}
