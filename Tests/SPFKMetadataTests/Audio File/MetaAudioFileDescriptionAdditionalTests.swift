import Foundation
import SPFKAudioBase
import Testing

@testable import SPFKMetadata

// MARK: - MetaAudioFileDescription computed properties

struct MetaAudioFileDescriptionPropertyTests {
    @Test func tempoGetSet() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        #expect(maf.tempo == nil)

        maf.tempo = Bpm(120)
        #expect(maf.tempo == Bpm(120))
        #expect(maf.tagProperties.tags[.bpm] != nil)
    }

    @Test func tempoNilWhenNoBpmTag() {
        let maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        #expect(maf.tempo == nil)
    }

    @Test func tempoSetNil() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.tempo = Bpm(140)
        #expect(maf.tempo != nil)

        maf.tempo = nil
        #expect(maf.tagProperties.tags[.bpm] == nil)
    }

    @Test func loudnessDescriptionFromTags() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.tagProperties.tags[.loudnessIntegrated] = "-14.0"
        maf.tagProperties.tags[.loudnessRange] = "9.5"
        maf.tagProperties.tags[.loudnessTruePeak] = "-1.0"
        maf.tagProperties.tags[.loudnessMaxMomentary] = "-10.0"
        maf.tagProperties.tags[.loudnessMaxShortTerm] = "-12.0"

        let desc = maf.loudnessDescription
        #expect(desc.loudnessIntegrated == -14.0)
        #expect(desc.loudnessRange == 9.5)
        #expect(desc.maxTruePeakLevel == -1.0)
        #expect(desc.maxMomentaryLoudness == -10.0)
        #expect(desc.maxShortTermLoudness == -12.0)
    }

    @Test func loudnessDescriptionEmpty() {
        let maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        let desc = maf.loudnessDescription
        #expect(desc.loudnessIntegrated == nil)
        #expect(desc.loudnessRange == nil)
        #expect(desc.maxTruePeakLevel == nil)
    }

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
            AudioMarkerDescription(name: "M1", startTime: 1.0),
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
            AudioMarkerDescription(name: nil, startTime: 0),
        ])

        let markers = maf.audioMarkers
        #expect(markers[0].name == "Marker 0")
    }
}

// MARK: - MetaAudioFileDescription convenience methods

struct MetaAudioFileDescriptionConvenienceTests {
    @Test func tagForKey() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.tagProperties.tags[.title] = "Test Song"

        #expect(maf.tag(for: .title) == "Test Song")
        #expect(maf.tag(for: .album) == nil)
    }

    @Test func customTagForKey() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.tagProperties.customTags["CUSTOM"] = "Value"

        #expect(maf.customTag(for: "CUSTOM") == "Value")
        #expect(maf.customTag(for: "NOPE") == nil)
    }

    @Test func setTag() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.set(tag: .artist, value: "Test Artist")

        #expect(maf.tagProperties.tags[.artist] == "Test Artist")
    }

    @Test func setCustomTag() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.set(customTag: "MY_KEY", value: "My Value")

        #expect(maf.tagProperties.customTags["MY_KEY"] == "My Value")
    }

    @Test func mergeBextCreatesIfNil() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        #expect(maf.bextDescription == nil)

        let dict: BEXTKeyDictionary = [
            .originator: "Test",
            .description: "Desc",
        ]

        maf.merge(bext: dict)

        #expect(maf.bextDescription != nil)
        #expect(maf.bextDescription?.originator == "Test")
        #expect(maf.bextDescription?.sequenceDescription == "Desc")
    }

    @Test func mergeBextUpdatesExisting() {
        var maf = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))
        maf.bextDescription = BEXTDescription()
        maf.bextDescription?.originator = "Original"

        let dict: BEXTKeyDictionary = [
            .originator: "Updated",
        ]

        maf.merge(bext: dict)

        #expect(maf.bextDescription?.originator == "Updated")
    }
}

// MARK: - MetaAudioFileDescription Codable

struct MetaAudioFileDescriptionCodableTests {
    @Test func codableRoundTripMinimal() throws {
        let original = MetaAudioFileDescription(url: URL(filePath: "/tmp/test.wav"))

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetaAudioFileDescription.self, from: data)

        #expect(decoded.url == original.url)
        #expect(decoded.fileType == nil)
        #expect(decoded.audioFormat == nil)
        #expect(decoded.bextDescription == nil)
        #expect(decoded.xmpMetadata == nil)
        #expect(decoded.iXMLMetadata == nil)
        #expect(decoded.markerCollection.count == 0)
    }

    @Test func codableRoundTripWithOptionals() throws {
        var original = MetaAudioFileDescription(
            url: URL(filePath: "/tmp/test.wav"),
            audioFormat: AudioFormatProperties(channelCount: 2, sampleRate: 48000, duration: 60),
            xmpMetadata: "<xmp>data</xmp>",
            iXMLMetadata: "<ixml>data</ixml>"
        )

        original.tagProperties.tags[.title] = "Test"
        original.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "Cue", startTime: 1.0),
        ])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetaAudioFileDescription.self, from: data)

        #expect(decoded.audioFormat?.sampleRate == 48000)
        #expect(decoded.audioFormat?.channelCount == 2)
        #expect(decoded.xmpMetadata == "<xmp>data</xmp>")
        #expect(decoded.iXMLMetadata == "<ixml>data</ixml>")
        #expect(decoded.tagProperties.tags[.title] == "Test")
        #expect(decoded.markerCollection.count == 1)
    }
}
