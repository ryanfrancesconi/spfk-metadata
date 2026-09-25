import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// `audioMarkers` is this package's extension, bridging the base marker collection to `AudioMarker`.
struct MetaAudioFileDescriptionAudioMarkerTests {
    @Test func audioMarkersFromCollection() {
        var maf = MetaAudioFileDescription(
            url: URL(filePath: "/tmp/test.wav"),
            audioFormat: AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 10)
        )

        maf.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "Intro", startTime: 0),
            AudioMarkerDescription(name: "Verse", startTime: 5.0),
        ])

        let markers = maf.audioMarkers
        #expect(markers.count == 2)
        #expect(markers[0].name == "Intro")
        #expect(markers[0].time == 0)
        #expect(markers[0].sampleRate == 44100)
        #expect(markers[1].name == "Verse")
        #expect(markers[1].time == 5.0)
    }

    @Test func audioMarkersEmpty() {
        let maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        #expect(maf.audioMarkers.isEmpty)
    }

    @Test func audioMarkersWithoutAudioFormat() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 1.0)
        ])

        let markers = maf.audioMarkers
        #expect(markers.count == 1)
        // sampleRate should fall back to 0 when no audioFormat
        #expect(markers[0].sampleRate == 0)
    }

    @Test func audioMarkersDefaultNameForNilName() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        // update(markerDescriptions:) auto-names nil markers, so name should be "Marker 0"
        maf.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: nil, startTime: 0)
        ])

        let markers = maf.audioMarkers
        #expect(markers[0].name == "Marker 0")
    }
}
