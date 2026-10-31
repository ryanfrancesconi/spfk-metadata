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

    private func overLimitFLAC() async throws -> (URL, Int) {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        let limit = try #require(AudioFileType.flac.markerStorage?.maximumMarkerCount)
        let count = limit + 200
        let duration = try #require(try await MetaAudioFileDescription(parsing: url).audioFormat?.duration)
        try #require(XiphChapterUtil.write(chapters(count, duration: duration), to: url.path))
        return (url, count)
    }

    @Test func xiphParseReadsEveryChapterOverTheLimit() async throws {
        let (url, count) = try await overLimitFLAC()
        #expect(try await markerCount(url) == count)
    }

    @Test func xiphMarkerSaveKeepsEveryChapterOverTheLimit() async throws {
        let (url, count) = try await overLimitFLAC()
        try await renameFirstAndSave(url)

        let data = try Data(contentsOf: url)
        #expect(data.range(of: Data("CHAPTER\(count - 1)=".utf8)) != nil)
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
