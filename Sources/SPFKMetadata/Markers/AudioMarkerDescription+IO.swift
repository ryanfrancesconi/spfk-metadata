// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC

extension AudioMarkerDescription {
    /// Creates an `AudioMarkerDescription` from a Core Audio RIFF cue point.
    ///
    /// Decodes the JSON metadata suffix from the marker name, if present, to recover
    /// `endTime`, `hexColor`, and `markerType` for markers written by ShadowTag.
    public init(riffMarker marker: AudioMarker) {
        let (name, duration, hexColor) = Self.decodeFileName(marker.name ?? "")

        self.init(
            name: name.isEmpty ? nil : name,
            startTime: marker.time,
            endTime: duration.map { marker.time + $0 },
            sampleRate: marker.sampleRate,
            markerID: Int(marker.markerID),
            hexColor: hexColor,
            markerType: duration != nil ? .region : .cue
        )
    }

    /// Creates an `AudioMarkerDescription` from a Chapter marker.
    ///
    /// Decodes the JSON color suffix from the chapter title, if present. The native
    /// `endTime` from the chapter format is authoritative and is not overridden by
    /// the JSON `d` key (which is only present in formats without native endTime support).
    public init(chapterMarker marker: ChapterMarker) {
        let (name, _, hexColor) = Self.decodeFileName(marker.name ?? "")
        self.init(
            name: name.isEmpty ? nil : name,
            startTime: marker.startTime,
            endTime: marker.endTime,
            hexColor: hexColor
        )
    }

    /// Converts to a `ChapterMarker` for writing via format-specific utilities.
    public var chapterMarker: ChapterMarker {
        ChapterMarker(name: name ?? "Marker", startTime: startTime, endTime: endTime ?? startTime)
    }

    /// Converts to a `ChapterMarker` with only the color JSON suffix encoded in the title.
    ///
    /// Used for MP3 and Xiph (FLAC/OGG/Opus) writes, where endTime is stored natively
    /// (ID3v2 CHAP element, Xiph CHAPTER000END) so the `d` key is redundant.
    /// The suffix is decoded back in `init(chapterMarker:)`.
    public var colorEncodedChapterMarker: ChapterMarker {
        ChapterMarker(name: colorEncodedName, startTime: startTime, endTime: endTime ?? startTime)
    }

    /// Converts to a `ChapterMarker` with the JSON metadata suffix encoded in the title.
    ///
    /// Used for MP4 chapter write, where the format has no native endTime or color fields.
    /// The suffix is decoded back in `AudioMarkerDescriptionCollection+Parser.swift`.
    public var fileEncodedChapterMarker: ChapterMarker {
        ChapterMarker(name: fileEncodedName, startTime: startTime, endTime: endTime ?? startTime)
    }
}

// MARK: - JSON name encoding

extension AudioMarkerDescription {
    /// Duration decimal places stored in the JSON suffix.
    /// 3 = millisecond precision (1 ms = 0.001 s).
    private static let durationDecimalPlaces = 3

    /// Returns the marker name with a compact JSON metadata suffix for use in file formats
    /// that have no native endTime or color fields (WAV/AIFF cue points, MP4 chapter titles).
    ///
    /// Only the fields that are present are included. Returns the plain name when no metadata
    /// needs encoding. Suffix format: `{"c":"RRGGBBAA","d":5.0}` (keys sorted alphabetically).
    public var fileEncodedName: String {
        let baseName = name ?? "Marker"
        var meta: [String: Any] = [:]

        if let endTime, endTime > startTime {
            let duration = endTime - startTime
            let scale = pow(10.0, Double(Self.durationDecimalPlaces))
            let rounded = (duration * scale).rounded() / scale

            if rounded > 0 {
                // NSDecimalNumber stores the value as an exact decimal string, so JSONSerialization
                // outputs "5.001" rather than the IEEE 754 representation "5.001000000000000045".
                meta["d"] = NSDecimalNumber(string: String(format: "%.\(Self.durationDecimalPlaces)f", rounded))
            }
        }

        if let colorString = hexColor?.stringValue {
            meta["c"] = colorString
        }

        guard !meta.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: meta, options: .sortedKeys),
              let json = String(data: data, encoding: .utf8)
        else { return baseName }

        return "\(baseName) \(json)"
    }

    /// Returns the marker name with only a color JSON suffix, for formats that store endTime natively
    /// (MP3 ID3v2 CHAP, Xiph CHAPTER000END). Returns the plain name when no color is set.
    ///
    /// Suffix format: `{"c":"RRGGBBAA"}`.
    public var colorEncodedName: String {
        let baseName = name ?? "Marker"
        guard let colorString = hexColor?.stringValue else { return baseName }

        let meta: [String: Any] = ["c": colorString]
        guard let data = try? JSONSerialization.data(withJSONObject: meta, options: .sortedKeys),
              let json = String(data: data, encoding: .utf8)
        else { return baseName }

        return "\(baseName) \(json)"
    }

    /// Parses a file-encoded marker name, returning the display name and any decoded metadata.
    ///
    /// Finds the last `{` in the string and attempts `JSONSerialization` from that position.
    /// If parsing fails (not valid JSON — e.g. `"intro {part a}"`), returns the full
    /// string as the name with no metadata decoded.
    ///
    /// - Parameter encoded: The raw name string as read from the audio file.
    /// - Returns: Display name (whitespace-trimmed), optional duration in seconds, optional hex color.
    public static func decodeFileName(_ encoded: String) -> (name: String, duration: TimeInterval?, hexColor: HexColor?) {
        guard let braceIndex = encoded.lastIndex(of: "{") else {
            return (encoded, nil, nil)
        }

        let jsonSubstring = String(encoded[braceIndex...])
        let baseName = String(encoded[encoded.startIndex ..< braceIndex])
            .trimmingCharacters(in: .whitespaces)

        guard let data = jsonSubstring.data(using: .utf8),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return (encoded, nil, nil) }

        let duration = meta["d"] as? TimeInterval
        let hexColor = (meta["c"] as? String).flatMap { HexColor(string: $0) }

        return (baseName, duration, hexColor)
    }
}
