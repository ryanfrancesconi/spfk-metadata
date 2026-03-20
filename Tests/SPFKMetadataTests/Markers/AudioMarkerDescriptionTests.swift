// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file), .serialized)
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
