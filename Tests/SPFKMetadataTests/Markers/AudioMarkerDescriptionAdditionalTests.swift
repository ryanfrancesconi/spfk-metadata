import Foundation
import SPFKUtils
import Testing

@testable import SPFKMetadata

// MARK: - AudioMarkerDescription Codable

struct AudioMarkerDescriptionCodableTests {
    @Test func codableRoundTrip() throws {
        let original = AudioMarkerDescription(
            name: "Marker 1",
            startTime: 1.5,
            endTime: 3.0,
            sampleRate: 44100,
            markerID: 42,
            hexColor: HexColor(string: "FF0000")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioMarkerDescription.self, from: data)

        #expect(decoded.name == "Marker 1")
        #expect(decoded.startTime == 1.5)
        #expect(decoded.endTime == 3.0)
        #expect(decoded.sampleRate == 44100)
        #expect(decoded.markerID == 42)
        #expect(decoded.hexColor?.stringValue == "FF0000FF")
    }

    @Test func codableMinimalFields() throws {
        let original = AudioMarkerDescription(name: nil, startTime: 0)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioMarkerDescription.self, from: data)

        #expect(decoded.name == nil)
        #expect(decoded.startTime == 0)
        #expect(decoded.endTime == nil)
        #expect(decoded.sampleRate == nil)
        #expect(decoded.markerID == nil)
        #expect(decoded.hexColor == nil)
    }
}

// MARK: - AudioMarkerDescription Comparable

struct AudioMarkerDescriptionComparableTests {
    @Test func sortByStartTime() {
        let m1 = AudioMarkerDescription(name: "B", startTime: 2.0)
        let m2 = AudioMarkerDescription(name: "A", startTime: 1.0)
        let m3 = AudioMarkerDescription(name: "C", startTime: 3.0)

        let sorted = [m1, m2, m3].sorted()
        #expect(sorted.map(\.startTime) == [1.0, 2.0, 3.0])
    }

    @Test func sortByNameWhenSameTime() {
        let m1 = AudioMarkerDescription(name: "Beta", startTime: 1.0)
        let m2 = AudioMarkerDescription(name: "Alpha", startTime: 1.0)

        let sorted = [m1, m2].sorted()
        #expect(sorted[0].name == "Alpha")
        #expect(sorted[1].name == "Beta")
    }
}

// MARK: - AudioMarkerDescription Equatable

struct AudioMarkerDescriptionEquatableTests {
    @Test func equalWithMarkerIDs() {
        let m1 = AudioMarkerDescription(name: "A", startTime: 1.0, markerID: 1)
        let m2 = AudioMarkerDescription(name: "B", startTime: 1.0, markerID: 1)

        #expect(m1 == m2)
    }

    @Test func notEqualDifferentIDs() {
        let m1 = AudioMarkerDescription(name: "A", startTime: 1.0, markerID: 1)
        let m2 = AudioMarkerDescription(name: "A", startTime: 1.0, markerID: 2)

        #expect(m1 != m2)
    }

    @Test func equalWithoutMarkerIDs() {
        let m1 = AudioMarkerDescription(name: "A", startTime: 1.0)
        let m2 = AudioMarkerDescription(name: "A", startTime: 1.0)

        #expect(m1 == m2)
    }

    @Test func notEqualWithoutMarkerIDsDifferentName() {
        let m1 = AudioMarkerDescription(name: "A", startTime: 1.0)
        let m2 = AudioMarkerDescription(name: "B", startTime: 1.0)

        #expect(m1 != m2)
    }

    @Test func notEqualDifferentStartTime() {
        let m1 = AudioMarkerDescription(name: "A", startTime: 1.0, markerID: 1)
        let m2 = AudioMarkerDescription(name: "A", startTime: 2.0, markerID: 1)

        #expect(m1 != m2)
    }

    @Test func notEqualDifferentEndTime() {
        let m1 = AudioMarkerDescription(name: "A", startTime: 1.0, endTime: 2.0, markerID: 1)
        let m2 = AudioMarkerDescription(name: "A", startTime: 1.0, endTime: 3.0, markerID: 1)

        #expect(m1 != m2)
    }
}

// MARK: - AudioMarkerDescription description

struct AudioMarkerDescriptionStringTests {
    @Test func descriptionBasic() {
        let m = AudioMarkerDescription(name: "Test", startTime: 1.5)
        let desc = m.description
        #expect(desc.contains("Test"))
        #expect(desc.contains("1.5"))
    }

    @Test func descriptionWithEndTime() {
        let m = AudioMarkerDescription(name: "Test", startTime: 1.0, endTime: 3.5)
        let desc = m.description
        #expect(desc.contains("..."))
        #expect(desc.contains("3.5"))
    }

    @Test func descriptionWithColor() {
        let m = AudioMarkerDescription(name: "Test", startTime: 0, hexColor: HexColor(string: "FF0000"))
        let desc = m.description
        #expect(desc.contains("Color:"))
        #expect(desc.contains("FF0000"))
    }

    @Test func descriptionWithMarkerID() {
        let m = AudioMarkerDescription(name: "Test", startTime: 0, markerID: 7)
        let desc = m.description
        #expect(desc.contains("ID: 7"))
    }

    @Test func descriptionUntitledWhenNilName() {
        let m = AudioMarkerDescription(name: nil, startTime: 0)
        #expect(m.description.contains("Untitled"))
    }

    @Test func debugDescription() {
        let m = AudioMarkerDescription(name: "Test", startTime: 1.0, markerID: 5)
        let debug = m.debugDescription
        #expect(debug.contains("AudioMarkerDescription"))
        #expect(debug.contains("Test"))
        #expect(debug.contains("1.0"))
    }

    @Test func noEndTimeRangeWhenEqual() {
        // endTime == startTime should not show range
        let m = AudioMarkerDescription(name: "X", startTime: 2.0, endTime: 2.0)
        #expect(!m.description.contains("..."))
    }
}
