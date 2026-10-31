// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A format reads back every marker up to its ``MarkerStorage/maximumMarkerCount``, and a format with
/// no limit reads back more than any limited one allows.
@Suite(.tags(.file))
final class MarkerCountLimitTests: BinTestCase {
    /// The largest count any format limits markers to.
    private static let largestLimit = [MarkerStorage.riffCues, .aiffMarks, .id3Chapters, .mp4Chapters, .xiphChapters, .coreAudio]
        .compactMap(\.maximumMarkerCount)
        .max() ?? 0

    private static func markers(_ count: Int, duration: TimeInterval) -> [AudioMarkerDescription] {
        let spacing = duration / Double(count + 1)
        return (0 ..< count).map {
            AudioMarkerDescription(name: "T\($0 + 1)", startTime: spacing * Double($0 + 1))
        }
    }

    private func roundTrip(_ fixture: URL, count: Int) async throws -> [AudioMarkerDescription] {
        let url = try copyToBin(url: fixture)
        var description = try await MetaAudioFileDescription(parsing: url)
        let duration = try #require(description.audioFormat?.duration)

        description.markerCollection.update(markerDescriptions: Self.markers(count, duration: duration))
        try description.save(dirtyFlags: [.markers])

        return try await MetaAudioFileDescription(parsing: url).markerCollection.markerDescriptions.sorted()
    }

    @Test(arguments: [AudioFileType.mp3, .flac, .aiff])
    func aLimitedFormatReadsBackItsLimit(fileType: AudioFileType) async throws {
        let fixture = switch fileType {
        case .mp3: TestBundleResources.shared.tabla_mp3
        case .flac: TestBundleResources.shared.tabla_flac
        default: TestBundleResources.shared.tabla_aif
        }
        let limit = try #require(fileType.markerStorage?.maximumMarkerCount)

        let markers = try await roundTrip(fixture, count: limit)

        #expect(markers.count == limit)
        #expect(markers.first?.name == "T1")
        #expect(markers.last?.name == "T\(limit)")
    }

    @Test func wavReadsBackMoreThanAnyLimitedFormat() async throws {
        let count = Self.largestLimit + 1
        let markers = try await roundTrip(TestBundleResources.shared.tabla_wav, count: count)

        #expect(markers.count == count)
        #expect(markers.last?.name == "T\(count)")
    }

    /// A metadata save does not write Core Audio's marker list, so this goes through its own writer.
    @Test(.tags(.slow)) func w64ReadsBackMoreThanAnyLimitedFormat() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.sine_w64)
        let description = try await MetaAudioFileDescription(parsing: url)
        let duration = try #require(description.audioFormat?.duration)
        let count = Self.largestLimit + 1

        try EmbeddedAudioMarkers.write(
            Self.markers(count, duration: duration), to: url, fileType: .w64,
            fileSampleRate: description.audioFormat?.sampleRate
        )

        let markers = try await MetaAudioFileDescription(parsing: url).markerCollection.markerDescriptions.sorted()
        #expect(markers.count == count)
        #expect(markers.last?.name == "T\(count)")
    }
}
