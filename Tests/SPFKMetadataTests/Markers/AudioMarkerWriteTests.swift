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

    /// MP3 opens read-write through AudioFile but refuses a marker list.
    @Test func markerWriteReportsRefusedMarkerList() throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let marker = AudioMarker(name: "Marker", time: 0.5, sampleRate: 44100, markerID: 0)

        #expect(AudioMarkerUtil.write([marker], to: url) == false)
    }

    /// Frame positions come from the file's own sample rate, whatever the marker carries.
    @Test(arguments: [0.0, 22050.0])
    func markerWritePositionUsesFileSampleRate(markerSampleRate: Double) throws {
        for fixture in [TestBundleResources.shared.tabla_wav, TestBundleResources.shared.tabla_aif] {
            let url = try copyToBin(url: fixture)
            let marker = AudioMarker(name: "Marker", time: 1, sampleRate: markerSampleRate, markerID: 0)
            #expect(AudioMarkerUtil.write([marker], to: url))

            let read = try #require((AudioMarkerUtil.read(url) as? [AudioMarker])?.first)
            #expect(abs(read.time - 1) < 0.001, "\(fixture.lastPathComponent)")
        }
    }

    /// A WAV whose codec Core Audio does not know still saves through TagLib, but not its markers.
    @Test func waveSaveReportsRefusedMarkerWrite() throws {
        let url = bin.appendingPathComponent("unknown-codec.wav")
        var data = try Data(contentsOf: TestBundleResources.shared.tabla_wav)
        let fmt = try #require(data.range(of: Data("fmt ".utf8)))
        data.replaceSubrange((fmt.upperBound + 4) ..< (fmt.upperBound + 6), with: [0x34, 0x12])
        try data.write(to: url)

        let waveFile = WaveFileC(path: url.path)
        #expect(waveFile.load())
        waveFile.markers = [AudioMarker(name: "Marker", time: 0.5, sampleRate: 44100, markerID: 0)]
        waveFile.markersNeedsSave = true

        #expect(waveFile.save() == false)
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
