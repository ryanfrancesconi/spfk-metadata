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
    private func roundTrip(_ fixture: URL, count: Int) async throws -> [AudioMarkerDescription] {
        let url = try copyToBin(url: fixture)
        var description = try await MetaAudioFileDescription(parsing: url)
        let duration = try #require(description.audioFormat?.duration)
        let spacing = duration / Double(count + 1)

        description.markerCollection.update(markerDescriptions: (0 ..< count).map {
            AudioMarkerDescription(name: "T\($0 + 1)", startTime: spacing * Double($0 + 1))
        })
        try description.save(dirtyFlags: [.markers])

        return try await MetaAudioFileDescription(parsing: url).markerCollection.markerDescriptions.sorted()
    }

    @Test(arguments: [AudioFileType.mp3, .flac])
    func aLimitedFormatReadsBackItsLimit(fileType: AudioFileType) async throws {
        let fixture = fileType == .mp3 ? TestBundleResources.shared.tabla_mp3 : TestBundleResources.shared.tabla_flac
        let limit = try #require(fileType.markerStorage?.maximumMarkerCount)

        let markers = try await roundTrip(fixture, count: limit)

        #expect(markers.count == limit)
        #expect(markers.first?.name == "T1")
        #expect(markers.last?.name == "T\(limit)")
    }

    @Test func wavReadsBackMoreThanAnyLimitedFormat() async throws {
        let count = 1500
        let markers = try await roundTrip(TestBundleResources.shared.tabla_wav, count: count)

        #expect(markers.count == count)
        #expect(markers.last?.name == "T\(count)")
    }
}
