// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
final class AudioMarkerWriteTests: BinTestCase {
    private let color = HexColor(string: "0000FFFF")
    private let longName = String(repeating: "日", count: 100) // 300 UTF-8 bytes

    private func regionMarker(name: String) -> AudioMarkerDescription {
        AudioMarkerDescription(
            name: name,
            startTime: 0.5,
            endTime: 13,
            hexColor: color,
            markerType: .region
        )
    }

    @Test func trimmedNameKeepsSuffixAndWholeCharacters() {
        let encoded = regionMarker(name: longName)
            .fileEncodedName(maxByteCount: AudioMarkerDescription.aiffMaxNameByteCount)

        #expect(encoded.utf8.count <= AudioMarkerDescription.aiffMaxNameByteCount)

        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName(encoded)
        #expect(name.isNotEmpty)
        #expect(longName.hasPrefix(name))
        #expect(duration == 12.5)
        #expect(hexColor == color)
    }

    @Test func nameWithinLimitIsUnchanged() {
        let marker = regionMarker(name: "Verse")
        #expect(marker.fileEncodedName(maxByteCount: 255) == marker.fileEncodedName)
    }

    @Test func longAIFFMarkerNameKeepsColorAndRegion() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        let marker = try await roundTrip(url: url)

        let name = try #require(marker.name)
        #expect(name.isNotEmpty)
        #expect(longName.hasPrefix(name))
        #expect(marker.hexColor == color)
        #expect(marker.markerType == .region)
        #expect(marker.endTime == 13)
    }

    @Test func longWAVMarkerNameIsNotTrimmed() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let asciiName = String(repeating: "x", count: 300)
        let marker = try await roundTrip(url: url, name: asciiName)

        #expect(marker.name == asciiName)
        #expect(marker.hexColor == color)
    }

    private func roundTrip(url: URL, name: String? = nil) async throws -> AudioMarkerDescription {
        var description = try await MetaAudioFileDescription(parsing: url)
        description.markerCollection.update(markerDescriptions: [regionMarker(name: name ?? longName)])
        try description.save(dirtyFlags: [.markers])

        let reparsed = try await MetaAudioFileDescription(parsing: url)
        #expect(reparsed.markerCollection.markerDescriptions.count == 1)
        return try #require(reparsed.markerCollection.markerDescriptions.first)
    }
}
