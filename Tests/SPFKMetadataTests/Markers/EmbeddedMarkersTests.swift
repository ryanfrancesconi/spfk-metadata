// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import SPFKUtils
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
final class EmbeddedMarkersTests: BinTestCase {
    /// Every type with marker storage: wider than `markerWriteTypes` by Core Audio's `.w64`.
    static let dispatched = Set(AudioFileType.allCases.filter { $0.markerStorage != nil })

    static let writable = TestBundleResources.shared.oneFilePerContainer.filter {
        AudioFileType(url: $0).map { dispatched.contains($0) } == true
    }

    static let writableWithTags = writable.filter { AudioFileType(url: $0)?.supportsMetadata == true }

    static let undispatched = TestBundleResources.shared.oneFilePerContainer.filter {
        AudioFileType(url: $0).map { !dispatched.contains($0) } == true
    }

    private let color = HexColor(string: "00FF00FF")

    private func copy(_ source: URL) throws -> URL {
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private func markers(sampleRate: Double) -> [AudioMarkerDescription] {
        [
            AudioMarkerDescription(name: "Intro", startTime: 0.5, sampleRate: sampleRate),
            AudioMarkerDescription(
                name: "Verse", startTime: 1, endTime: 2, sampleRate: sampleRate, hexColor: color, markerType: .region
            ),
        ]
    }

    @Test(arguments: writable)
    func writeRoundTrips(source: URL) async throws {
        try await roundTrip(source)
    }

    private func roundTrip(_ source: URL) async throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))
        let sampleRate = try #require(try await MetaAudioFileDescription(parsing: url).audioFormat?.sampleRate)

        try EmbeddedMarkers.write(markers(sampleRate: sampleRate), to: url, fileType: fileType)

        let readBack = try await AudioMarkerDescriptionCollection(url: url).markerDescriptions
        try #require(readBack.count == 2, "\(fileType)")

        #expect(readBack[0].name == "Intro")
        #expect(abs(readBack[0].startTime - 0.5) < 0.001)

        #expect(readBack[1].name == "Verse")
        #expect(abs(readBack[1].startTime - 1) < 0.001)
        #expect(abs((readBack[1].endTime ?? 0) - 2) < 0.001, "\(fileType)")
        #expect(readBack[1].hexColor == color, "\(fileType)")
    }

    @Test(arguments: writable)
    func removeAllLeavesNone(source: URL) async throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))
        let sampleRate = try #require(try await MetaAudioFileDescription(parsing: url).audioFormat?.sampleRate)

        try EmbeddedMarkers.write(markers(sampleRate: sampleRate), to: url, fileType: fileType)
        #expect(try EmbeddedMarkers.removeAll(from: url, fileType: fileType))

        let readBack = try await AudioMarkerDescriptionCollection(url: url).markerDescriptions
        #expect(readBack.isEmpty, "\(fileType)")
    }

    @Test(arguments: writableWithTags)
    func writeLeavesTagsAlone(source: URL) async throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))
        let before = try TagProperties(url: url)

        try EmbeddedMarkers.write(markers(sampleRate: 44100), to: url, fileType: fileType)

        #expect(try TagProperties(url: url).data == before.data, "\(fileType)")
    }

    @Test(arguments: undispatched)
    func unsupportedTypeThrows(source: URL) throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))

        #expect(throws: MetadataError.unsupportedFormat(fileType, .markers)) {
            try EmbeddedMarkers.write(markers(sampleRate: 44100), to: url, fileType: fileType)
        }

        #expect(throws: MetadataError.unsupportedFormat(fileType, .markers)) {
            try EmbeddedMarkers.removeAll(from: url, fileType: fileType)
        }
    }

    @Test func writeToMissingFileThrows() {
        let url = bin.appendingPathComponent("missing.mp3")

        #expect(throws: MetadataError.writeFailed(.markers, url)) {
            try EmbeddedMarkers.write(markers(sampleRate: 44100), to: url, fileType: .mp3)
        }
    }
}
