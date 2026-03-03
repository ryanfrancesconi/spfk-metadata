// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase

public struct AudioMarkerDescriptionCollection: Hashable, Sendable {
    public private(set) var markerDescriptions: [AudioMarkerDescription] = []

    public var count: Int { markerDescriptions.count }

    public var allIDs: [Int] {
        markerDescriptions.compactMap(\.markerID)
    }

    public var highestID: Int {
        markerDescriptions.compactMap(\.markerID).sorted().last ?? -1
    }

    public init(markerDescriptions: [AudioMarkerDescription] = []) {
        update(markerDescriptions: markerDescriptions)
    }
}

extension AudioMarkerDescriptionCollection: Codable {
    enum CodingKeys: String, CodingKey {
        case markerDescriptions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try update(markerDescriptions: container.decode([AudioMarkerDescription].self, forKey: .markerDescriptions))
        sort()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(markerDescriptions, forKey: .markerDescriptions)
    }
}

extension AudioMarkerDescriptionCollection {
    public mutating func update(markerDescriptions: [AudioMarkerDescription]) {
        var markerDescriptions = markerDescriptions.sorted()

        for i in 0 ..< markerDescriptions.count {
            markerDescriptions[i].markerID = i

            if markerDescriptions[i].name == nil {
                markerDescriptions[i].name = "Marker \(i)"
            }
        }

        self.markerDescriptions = markerDescriptions
    }

    public mutating func insert(markerDescriptions incoming: [AudioMarkerDescription]) throws {
        let incoming = incoming.filter { incomingMarker in
            !markerDescriptions.contains(where: { marker in
                marker.startTime == incomingMarker.startTime
            })
        }

        for markerDescription in incoming {
            _ = try insertAndIncrementID(markerDescription: markerDescription)
        }
    }

    public mutating func sort() {
        markerDescriptions.sort()
    }

    public mutating func insertAndIncrementID(markerDescription: AudioMarkerDescription) throws -> AudioMarkerDescription {
        let nextID = highestID + 1
        var markerDescription = markerDescription

        guard !allIDs.contains(nextID) else {
            throw NSError(description: "ID \(nextID) is already in the collection: \(allIDs)")
        }

        markerDescription.markerID = nextID

        if markerDescription.name == nil {
            markerDescription.name = "Marker \(nextID)"
        }

        markerDescriptions.append(markerDescription)
        sort()

        return markerDescription
    }

    public mutating func remove(markerID: Int) throws {
        for i in 0 ..< markerDescriptions.count where markerDescriptions[i].markerID == markerID {
            markerDescriptions.remove(at: i)
            sort()
            return
        }

        throw NSError(description: "Failed to find markerID \(markerID)")
    }

    public mutating func update(markerID: Int, markerDescription: AudioMarkerDescription) throws {
        for i in 0 ..< markerDescriptions.count where markerDescriptions[i].markerID == markerID {
            markerDescriptions[i] = markerDescription
            sort()
            return
        }

        throw NSError(description: "Failed to find markerID \(markerID), all ids are \(markerDescriptions.compactMap(\.markerID))")
    }
}
