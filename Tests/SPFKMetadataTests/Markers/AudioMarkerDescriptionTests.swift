// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
class AudioMarkerDescriptionCollectionTests: BinTestCase {
    @Test(arguments: TestBundleResources.shared.markerFormats)
    func parseFormat(url: URL) async throws {
        let collection = try await AudioMarkerDescriptionCollection(url: url)
        let markers = collection.markerDescriptions

        #expect(markers.count == 5, "\(url.lastPathComponent)")

        let names = markers.compactMap(\.name)
        let startTimes = markers.compactMap(\.startTime)

        #expect(names == ["Marker 0", "Marker 1", "Marker 2", "Marker 3", "Marker 4"], "\(url.lastPathComponent)")
        #expect(startTimes == [0.0, 1.0, 2.0, 3.0, 4.0], "\(url.lastPathComponent)")
    }

    // MARK: - mergeColors

    @Test func mergeColorsById() {
        let red = HexColor(string: "FF0000FF")!
        let previous = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "A", startTime: 0, markerID: 0, hexColor: red),
        ])
        var fresh = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "A", startTime: 0, markerID: 0),
        ])
        fresh.mergeColors(from: previous)
        #expect(fresh.markerDescriptions[0].hexColor?.stringValue == "FF0000FF")
    }

    @Test func mergeColorsFallbackByNameAndTime() {
        let blue = HexColor(string: "0000FFFF")!
        // previous has markerID 5; fresh has a different ID (99) but same name+startTime
        let previous = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "B", startTime: 2.5, markerID: 5, hexColor: blue),
        ])
        var fresh = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "B", startTime: 2.5, markerID: 99),
        ])
        fresh.mergeColors(from: previous)
        #expect(fresh.markerDescriptions[0].hexColor?.stringValue == "0000FFFF")
    }

    @Test func mergeColorsPreservesExistingColor() {
        let red = HexColor(string: "FF0000FF")!
        let green = HexColor(string: "00FF00FF")!
        let previous = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "A", startTime: 0, markerID: 0, hexColor: red),
        ])
        var fresh = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "A", startTime: 0, markerID: 0, hexColor: green),
        ])
        fresh.mergeColors(from: previous)
        // existing color (green) must not be overwritten by previous (red)
        #expect(fresh.markerDescriptions[0].hexColor?.stringValue == "00FF00FF")
    }

    @Test func merging() async throws {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "Marker 1", startTime: 0),
            AudioMarkerDescription(name: "Marker 2", startTime: 1),
            AudioMarkerDescription(name: "Marker 3", startTime: 2),
        ])

        try collection.insert(markerDescriptions: [
            AudioMarkerDescription(name: "Marker 4", startTime: 3)
        ])

        // startTime exists, so this marker should be ignored
        try collection.insert(markerDescriptions: [
            AudioMarkerDescription(name: "Marker 5", startTime: 3)
        ])

        #expect(collection.count == 4)
        #expect(collection.allIDs == [0, 1, 2, 3])
        #expect(collection.highestID == 3)
    }

    // MARK: - chapterMarker reverse conversion

    @Test func chapterMarkerConversion() {
        let desc = AudioMarkerDescription(name: "Test", startTime: 1.5, endTime: 3.0)
        let chapter = desc.chapterMarker

        #expect(chapter.name == "Test")
        #expect(chapter.startTime == 1.5)
        #expect(chapter.endTime == 3.0)
    }

    @Test func chapterMarkerConversionNilName() {
        let desc = AudioMarkerDescription(name: nil, startTime: 2.0, endTime: 4.0)
        let chapter = desc.chapterMarker

        #expect(chapter.name == "Marker")
        #expect(chapter.startTime == 2.0)
        #expect(chapter.endTime == 4.0)
    }

    @Test func chapterMarkerConversionNilEndTime() {
        let desc = AudioMarkerDescription(name: "Cue", startTime: 5.0)
        let chapter = desc.chapterMarker

        #expect(chapter.name == "Cue")
        #expect(chapter.startTime == 5.0)
        // endTime defaults to startTime when nil
        #expect(chapter.endTime == 5.0)
    }

    @Test func chapterMarkersCollectionConversion() {
        let collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "A", startTime: 0, endTime: 1),
            AudioMarkerDescription(name: "B", startTime: 1, endTime: 2),
            AudioMarkerDescription(name: "C", startTime: 2, endTime: 3),
        ])

        let chapters = collection.chapterMarkers

        #expect(chapters.count == 3)
        #expect(chapters.map(\.name) == ["A", "B", "C"])
        #expect(chapters.map(\.startTime) == [0, 1, 2])
        #expect(chapters.map(\.endTime) == [1, 2, 3])
    }
}

// MARK: - JSON name encoding

@Suite
struct AudioMarkerDescriptionEncodingTests {
    // fileEncodedName: plain cue with no metadata returns bare name, no JSON suffix
    @Test func encodedNamePlainCue() {
        let desc = AudioMarkerDescription(name: "Intro", startTime: 1.0)
        #expect(desc.fileEncodedName == "Intro")
    }

    // fileEncodedName: cue with endTime == startTime produces no duration
    @Test func encodedNameEndTimeEqualStart() {
        let desc = AudioMarkerDescription(name: "Point", startTime: 3.0, endTime: 3.0)
        #expect(desc.fileEncodedName == "Point")
    }

    // fileEncodedName: region with duration encodes d key; decode recovers name and duration
    @Test func encodedNameWithDuration() {
        let desc = AudioMarkerDescription(name: "Loop", startTime: 1.0, endTime: 6.0)
        let encoded = desc.fileEncodedName
        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName(encoded)
        #expect(name == "Loop")
        #expect(duration == 5.0)
        #expect(hexColor == nil)
    }

    // fileEncodedName: cue with only hexColor encodes c key; decode recovers color, nil duration
    @Test func encodedNameWithColorOnly() {
        let hex = HexColor(string: "FF0000FF")!
        let desc = AudioMarkerDescription(name: "Cue", startTime: 1.0, hexColor: hex)
        let encoded = desc.fileEncodedName
        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName(encoded)
        #expect(name == "Cue")
        #expect(duration == nil)
        #expect(hexColor?.stringValue == "FF0000FF")
    }

    // fileEncodedName: region with both duration and color; decode recovers both
    @Test func encodedNameWithDurationAndColor() {
        let hex = HexColor(string: "00FF00FF")!
        let desc = AudioMarkerDescription(name: "Region", startTime: 2.0, endTime: 7.5, hexColor: hex)
        let encoded = desc.fileEncodedName
        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName(encoded)
        #expect(name == "Region")
        #expect(duration == 5.5)
        #expect(hexColor?.stringValue == "00FF00FF")
    }

    // fileEncodedName: nil name defaults to "Marker" as base name
    @Test func encodedNameNilName() {
        let desc = AudioMarkerDescription(name: nil, startTime: 1.0, endTime: 4.0)
        let encoded = desc.fileEncodedName
        let (name, duration, _) = AudioMarkerDescription.decodeFileName(encoded)
        #expect(name == "Marker")
        #expect(duration == 3.0)
    }

    // fileEncodedName: JSON keys are sorted alphabetically (c before d)
    @Test func encodedNameKeysSorted() {
        let hex = HexColor(string: "AABBCCFF")!
        let desc = AudioMarkerDescription(name: "X", startTime: 0.0, endTime: 1.0, hexColor: hex)
        let encoded = desc.fileEncodedName
        // Sorted keys: "c" < "d", so {"c":...,"d":...} not {"d":...,"c":...}
        if let braceRange = encoded.range(of: "{") {
            let json = String(encoded[braceRange.lowerBound...])
            let cIndex = json.range(of: "\"c\"")?.lowerBound
            let dIndex = json.range(of: "\"d\"")?.lowerBound
            if let c = cIndex, let d = dIndex {
                #expect(c < d)
            }
        }
    }

    // decodeFileName: string with no brace returns it unchanged, nil metadata
    @Test func decodeFileNameNoBrace() {
        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName("Simple Name")
        #expect(name == "Simple Name")
        #expect(duration == nil)
        #expect(hexColor == nil)
    }

    // decodeFileName: name containing { but not valid JSON passes through unchanged
    @Test func decodeFileNameBraceNotJSON() {
        let input = "intro {part a}"
        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName(input)
        #expect(name == input)
        #expect(duration == nil)
        #expect(hexColor == nil)
    }

    // decodeFileName: empty string returns empty name, nil metadata
    @Test func decodeFileNameEmpty() {
        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName("")
        #expect(name == "")
        #expect(duration == nil)
        #expect(hexColor == nil)
    }

    // decodeFileName: unknown JSON keys are ignored; known fields still extracted
    @Test func decodeFileNameUnknownKeys() {
        let input = #"Name {"x":99,"d":3.0}"#
        let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName(input)
        #expect(name == "Name")
        #expect(duration == 3.0)
        #expect(hexColor == nil)
    }

    // Duration rounding: JSON suffix contains no more than 3 decimal places, no floating-point noise
    @Test func durationRounding() {
        // 1/3 has infinite decimal expansion; verify the raw JSON string is clean (e.g. "0.333")
        let desc = AudioMarkerDescription(name: "X", startTime: 0.0, endTime: 1.0 / 3.0)
        let encoded = desc.fileEncodedName

        if let dRange = encoded.range(of: "\"d\":") {
            let afterD = encoded[dRange.upperBound...]
            let numberStr = afterD.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" })
            if let dotIndex = numberStr.firstIndex(of: ".") {
                let decimals = numberStr[numberStr.index(after: dotIndex)...]
                #expect(decimals.count <= 3, "JSON duration had more than 3dp: \(encoded)")
            }
        }

        let (_, duration, _) = AudioMarkerDescription.decodeFileName(encoded)
        #expect(duration == 0.333)
    }

    // init(riffMarker:) decodes JSON suffix to recover endTime, hexColor, and markerType
    @Test func riffMarkerInitDecoded() {
        let hex = HexColor(string: "AABB00FF")!
        let original = AudioMarkerDescription(name: "Segment", startTime: 3.0, endTime: 8.0, hexColor: hex)
        let encodedName = original.fileEncodedName

        let marker = AudioMarker(name: encodedName, time: 3.0, sampleRate: 44100, markerID: 0)
        let decoded = AudioMarkerDescription(riffMarker: marker)

        #expect(decoded.name == "Segment")
        #expect(decoded.startTime == 3.0)
        #expect(decoded.endTime == 8.0)
        #expect(decoded.hexColor?.stringValue == "AABB00FF")
        #expect(decoded.markerType == .region)
    }

    // init(riffMarker:) without JSON suffix produces a plain cue with no endTime
    @Test func riffMarkerInitPlainCue() {
        let marker = AudioMarker(name: "Cue Point", time: 5.0, sampleRate: 44100, markerID: 1)
        let decoded = AudioMarkerDescription(riffMarker: marker)

        #expect(decoded.name == "Cue Point")
        #expect(decoded.startTime == 5.0)
        #expect(decoded.endTime == nil)
        #expect(decoded.markerType == .cue)
    }
}
