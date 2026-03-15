// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKUtils

/// Format-agnostic audio marker representing a point or region within an audio file.
///
/// Stores RIFF cue points, ID3 CHAP frames, or AVFoundation chapter markers in a unified
/// `Codable`, `Sendable` type. Ordered by start time (then name) for sorted collections.
public struct AudioMarkerDescription: Hashable, Sendable, Equatable, Comparable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard let id1 = lhs.markerID, let id2 = rhs.markerID else {
            //
            return lhs.name == rhs.name &&
                lhs.startTime == rhs.startTime &&
                lhs.endTime == rhs.endTime
        }

        return id1 == id2 &&
            lhs.startTime == rhs.startTime &&
            lhs.endTime == rhs.endTime
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        guard lhs.startTime != rhs.startTime else {
            if let name1 = lhs.name, let name2 = rhs.name {
                return name1.standardCompare(with: name2)
            }

            // If either name is nil, they can't be ordered by name
            return false
        }

        return lhs.startTime < rhs.startTime
    }

    /// Display name of the marker.
    public var name: String?

    /// Start position in seconds.
    public var startTime: TimeInterval

    /// End position in seconds for region markers. `nil` for point markers.
    public var endTime: TimeInterval?

    /// Sample rate of the source file (used for sample-accurate positioning).
    public var sampleRate: Double?

    /// Unique ID within its collection, assigned automatically on insertion.
    public var markerID: Int?

    /// Optional display color as a hex string (e.g., "#FF0000").
    public var hexColor: HexColor?

    public init(
        name: String?,
        startTime: TimeInterval,
        endTime: TimeInterval? = nil,
        sampleRate: Double? = nil,
        markerID: Int? = nil,
        hexColor: HexColor? = nil
    ) {
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.sampleRate = sampleRate
        self.markerID = markerID
        self.hexColor = hexColor
    }

}

extension AudioMarkerDescription: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case startTime
        case endTime
        case sampleRate
        case markerID
        case hexColor
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        endTime = try? container.decodeIfPresent(TimeInterval.self, forKey: .endTime)
        sampleRate = try? container.decodeIfPresent(Double.self, forKey: .sampleRate)
        markerID = try? container.decodeIfPresent(Int.self, forKey: .markerID)
        hexColor = try? container.decodeIfPresent(HexColor.self, forKey: .hexColor)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(startTime, forKey: .startTime)
        try? container.encodeIfPresent(name, forKey: .name)
        try? container.encodeIfPresent(endTime, forKey: .endTime)
        try? container.encodeIfPresent(sampleRate, forKey: .sampleRate)
        try? container.encodeIfPresent(markerID, forKey: .markerID)
        try? container.encodeIfPresent(hexColor, forKey: .hexColor)
    }
}

extension AudioMarkerDescription: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        let name = name ?? "Untitled"
        let start = startTime.truncated(decimalPlaces: 3)

        var color = ""
        if let value = hexColor?.stringValue {
            color = ", Color: \(value)"
        }

        var id = ""
        if let markerID {
            id = ", ID: \(markerID)"
        }

        var end = ""
        if let endTime, endTime != startTime {
            end = "...\(endTime.truncated(decimalPlaces: 3))s"
        }

        return "\(name) @ \(start)s\(end)\(color)\(id)"
    }

    public var debugDescription: String {
        "AudioMarkerDescription(name: \(name ?? "nil"), startTime: \(startTime), "
            + "endTime: \(endTime?.string ?? "nil"), sampleRate: \(sampleRate?.string ?? "nil"), "
            + "markerID: \(markerID?.string ?? "nil"), hexColor: \(hexColor?.stringValue ?? "nil")"
    }
}
