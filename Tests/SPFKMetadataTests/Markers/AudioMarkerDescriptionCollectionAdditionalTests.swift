import Foundation
@testable import SPFKMetadata
import Testing

struct AudioMarkerDescriptionCollectionAdditionalTests {
    // MARK: - remove

    @Test func removeMarkerByID() throws {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 0),
            AudioMarkerDescription(name: "M2", startTime: 1),
            AudioMarkerDescription(name: "M3", startTime: 2),
        ])

        #expect(collection.count == 3)
        try collection.remove(markerID: 1)
        #expect(collection.count == 2)
        #expect(!collection.allIDs.contains(1))
    }

    @Test func removeMarkerByIDNotFound() {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 0),
        ])

        #expect(throws: Error.self) {
            try collection.remove(markerID: 999)
        }
    }

    // MARK: - update

    @Test func updateMarker() throws {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 0),
            AudioMarkerDescription(name: "M2", startTime: 1),
        ])

        var updated = AudioMarkerDescription(name: "M2 Updated", startTime: 1.5)
        updated.markerID = 1

        try collection.update(markerID: 1, markerDescription: updated)

        let marker = collection.markerDescriptions.first(where: { $0.markerID == 1 })
        #expect(marker?.name == "M2 Updated")
        #expect(marker?.startTime == 1.5)
    }

    @Test func updateMarkerWithNilDescriptionID() throws {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 0),
        ])

        // markerID parameter is used to locate the marker, so nil on the description is fine
        let noID = AudioMarkerDescription(name: "Updated", startTime: 0.5)
        try collection.update(markerID: 0, markerDescription: noID)

        let marker = collection.markerDescriptions.first(where: { $0.markerID == nil })
        #expect(marker?.name == "Updated")
    }

    @Test func updateMarkerNotFound() {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 0),
        ])

        var marker = AudioMarkerDescription(name: "X", startTime: 0)
        marker.markerID = 999

        #expect(throws: Error.self) {
            try collection.update(markerID: 999, markerDescription: marker)
        }
    }

    // MARK: - insertAndIncrementID

    @Test func insertAndIncrementID() throws {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 0),
        ])

        let marker = AudioMarkerDescription(name: nil, startTime: 5)
        let inserted = try collection.insertAndIncrementID(markerDescription: marker)

        #expect(inserted.markerID == 1)
        #expect(inserted.name == "Marker 1") // auto-named
        #expect(collection.count == 2)
    }

    // MARK: - update(markerDescriptions:) reassigns IDs

    @Test func updateReassignsIDs() {
        var collection = AudioMarkerDescriptionCollection()
        collection.update(markerDescriptions: [
            AudioMarkerDescription(name: "C", startTime: 3, markerID: 99),
            AudioMarkerDescription(name: "A", startTime: 1, markerID: 50),
            AudioMarkerDescription(name: "B", startTime: 2, markerID: 75),
        ])

        // should be sorted and IDs reassigned sequentially
        #expect(collection.markerDescriptions[0].markerID == 0)
        #expect(collection.markerDescriptions[1].markerID == 1)
        #expect(collection.markerDescriptions[2].markerID == 2)

        // should be sorted by startTime
        #expect(collection.markerDescriptions[0].startTime == 1)
        #expect(collection.markerDescriptions[1].startTime == 2)
        #expect(collection.markerDescriptions[2].startTime == 3)
    }

    @Test func updateAutoNamesNilMarkers() {
        var collection = AudioMarkerDescriptionCollection()
        collection.update(markerDescriptions: [
            AudioMarkerDescription(name: nil, startTime: 0),
            AudioMarkerDescription(name: "Named", startTime: 1),
            AudioMarkerDescription(name: nil, startTime: 2),
        ])

        #expect(collection.markerDescriptions[0].name == "Marker 0")
        #expect(collection.markerDescriptions[1].name == "Named")
        #expect(collection.markerDescriptions[2].name == "Marker 2")
    }

    // MARK: - Codable

    @Test func codableRoundTrip() throws {
        let collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "M1", startTime: 0),
            AudioMarkerDescription(name: "M2", startTime: 1),
            AudioMarkerDescription(name: "M3", startTime: 2),
        ])

        let data = try JSONEncoder().encode(collection)
        let decoded = try JSONDecoder().decode(AudioMarkerDescriptionCollection.self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded.markerDescriptions[0].name == "M1")
        #expect(decoded.markerDescriptions[1].name == "M2")
        #expect(decoded.markerDescriptions[2].name == "M3")
    }

    @Test func codableEmpty() throws {
        let collection = AudioMarkerDescriptionCollection()
        let data = try JSONEncoder().encode(collection)
        let decoded = try JSONDecoder().decode(AudioMarkerDescriptionCollection.self, from: data)

        #expect(decoded.count == 0)
    }

    // MARK: - highestID / allIDs

    @Test func highestIDEmpty() {
        let collection = AudioMarkerDescriptionCollection()
        #expect(collection.highestID == -1)
    }

    @Test func allIDsEmpty() {
        let collection = AudioMarkerDescriptionCollection()
        #expect(collection.allIDs.isEmpty)
    }

    // MARK: - insert deduplication

    @Test func insertIgnoresDuplicateStartTimes() throws {
        var collection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "Existing", startTime: 1.0),
        ])

        try collection.insert(markerDescriptions: [
            AudioMarkerDescription(name: "Duplicate", startTime: 1.0),
            AudioMarkerDescription(name: "New", startTime: 2.0),
        ])

        #expect(collection.count == 2)
        // "Duplicate" at startTime 1.0 should have been ignored
        let names = collection.markerDescriptions.compactMap(\.name)
        #expect(!names.contains("Duplicate"))
        #expect(names.contains("New"))
    }
}
