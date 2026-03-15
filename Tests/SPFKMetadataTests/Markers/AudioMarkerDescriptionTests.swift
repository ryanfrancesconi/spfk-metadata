// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.serialized)
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
}
