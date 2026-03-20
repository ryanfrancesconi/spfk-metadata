// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.tags(.file), .serialized)
class AudioMarkerTests: BinTestCase {
    @Test func parseMarkers() async throws {
        let markers = AudioMarkerUtil.getMarkers(TestBundleResources.shared.wav_bext_v2) as? [AudioMarker] ?? []

        Log.debug(markers.map { ($0.name ?? "nil") + " @ \($0.time) \($0.timecode)" })
        #expect(markers.count == 3)
    }

    @Test func writeMarkers() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        let markers: [AudioMarker] = [
            AudioMarker(name: "New 1", time: 2, sampleRate: 44100, markerID: 0),
            AudioMarker(name: "New 2", time: 4, sampleRate: 44100, markerID: 1),
        ]

        #expect(
            AudioMarkerUtil.update(tmpfile, markers: markers)
        )

        #expect(
            FileManager.default.fileExists(atPath: tmpfile.path)
        )

        let editedMarkers = AudioMarkerUtil.getMarkers(tmpfile) as? [AudioMarker] ?? []
        let names = editedMarkers.compactMap { $0.name }
        let times = editedMarkers.map { $0.time }

        #expect(editedMarkers.count == 2)
        Log.debug(editedMarkers.map { ($0.name ?? "nil") + " @ \($0.time)" })

        #expect(names == ["New 1", "New 2"])
        #expect(times == [2, 4])
    }

    @Test func removeMarkers() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        #expect(AudioMarkerUtil.removeAllMarkers(tmpfile))

        let editedMarkers = AudioMarkerUtil.getMarkers(tmpfile) as? [AudioMarker] ?? []
        Log.debug(editedMarkers.map { ($0.name ?? "nil") + " @ \($0.time)" })
        #expect(editedMarkers.count == 0)
    }

    @Test func timestampPrecision() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        let markers: [AudioMarker] = [
            AudioMarker(name: "Precise", time: 1.23456, sampleRate: 44100, markerID: 0),
            AudioMarker(name: "SubSample", time: 0.00001, sampleRate: 96000, markerID: 1),
        ]

        #expect(AudioMarkerUtil.update(tmpfile, markers: markers))

        let readBack = AudioMarkerUtil.getMarkers(tmpfile) as? [AudioMarker] ?? []

        #expect(readBack.count == 2)
        // Sample-based precision: 1 sample at 44100 Hz ≈ 0.000023s
        #expect(abs(readBack[0].time - 1.23456) < 0.001)
        #expect(abs(readBack[1].time - 0.00001) < 0.001)
    }

    // MARK: - AIFF

    @Test func writeAndReadMarkersAIFF() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_aif)

        let markers: [AudioMarker] = [
            AudioMarker(name: "Start", time: 0.5, sampleRate: 48000, markerID: 0),
            AudioMarker(name: "Middle", time: 2.5, sampleRate: 48000, markerID: 1),
            AudioMarker(name: "End", time: 4.0, sampleRate: 48000, markerID: 2),
        ]

        #expect(AudioMarkerUtil.update(tmpfile, markers: markers))

        let readBack = AudioMarkerUtil.getMarkers(tmpfile) as? [AudioMarker] ?? []

        #expect(readBack.count == 3)
        #expect(readBack.compactMap(\.name) == ["Start", "Middle", "End"])
        #expect(abs(readBack[0].time - 0.5) < 0.001)
        #expect(abs(readBack[1].time - 2.5) < 0.001)
        #expect(abs(readBack[2].time - 4.0) < 0.001)
    }

    @Test func removeMarkersAIFF() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_aif)

        let markers: [AudioMarker] = [
            AudioMarker(name: "Temp", time: 1.0, sampleRate: 48000, markerID: 0),
        ]

        #expect(AudioMarkerUtil.update(tmpfile, markers: markers))
        #expect((AudioMarkerUtil.getMarkers(tmpfile) as? [AudioMarker])?.count == 1)

        #expect(AudioMarkerUtil.removeAllMarkers(tmpfile))
        #expect((AudioMarkerUtil.getMarkers(tmpfile) as? [AudioMarker] ?? []).count == 0)
    }

    @Test func timestampPrecisionAIFF() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_aif)

        let markers: [AudioMarker] = [
            AudioMarker(name: "Precise", time: 3661.123, sampleRate: 48000, markerID: 0),
        ]

        #expect(AudioMarkerUtil.update(tmpfile, markers: markers))

        let readBack = AudioMarkerUtil.getMarkers(tmpfile) as? [AudioMarker] ?? []

        #expect(readBack.count == 1)
        #expect(readBack[0].name == "Precise")
        #expect(abs(readBack[0].time - 3661.123) < 0.001)
    }
}
