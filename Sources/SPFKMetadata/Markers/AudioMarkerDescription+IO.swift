// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
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

    /// From an MP4 chapter, whose title's suffix carries end time as well as color.
    init(fileEncodedChapter chapter: ChapterMarker) {
        let (name, duration, hexColor) = Self.decodeFileName(chapter.name ?? "")

        self.init(
            name: name.isEmpty ? nil : name,
            startTime: chapter.startTime,
            endTime: duration.map { chapter.startTime + $0 },
            hexColor: hexColor,
            markerType: duration != nil ? .region : .cue
        )
    }

    /// Converts to an `AudioMarker` for WAV/AIFF writing, with endTime and color in the name suffix.
    public func audioMarker(markerID: Int, fileType: AudioFileType?, fileSampleRate: Double? = nil) -> AudioMarker {
        let isAIFF = fileType == .aiff || fileType == .aifc

        return AudioMarker(
            name: isAIFF ? fileEncodedName(maxByteCount: Self.aiffMaxNameByteCount) : fileEncodedName,
            time: startTime,
            sampleRate: fileSampleRate ?? sampleRate ?? 0,
            markerID: Int32(markerID)
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
        guard let suffix = fileEncodingSuffix else { return baseName }
        return "\(baseName) \(suffix)"
    }

    /// Longest marker name, in UTF-8 bytes, that an AIFF `MARK` chunk holds. Core Audio replaces
    /// a longer name with `"?"`, losing the JSON suffix with it.
    public static let aiffMaxNameByteCount = 255

    /// `fileEncodedName`, with the display name trimmed so the whole string fits in
    /// `maxByteCount` UTF-8 bytes. The suffix is kept whole; only the name is shortened.
    public func fileEncodedName(maxByteCount: Int) -> String {
        let baseName = name ?? "Marker"
        let suffix = fileEncodingSuffix.map { " \($0)" } ?? ""
        let budget = maxByteCount - suffix.utf8.count

        guard budget >= 0 else { return Self.prefix(of: baseName, maxByteCount: maxByteCount) }

        return Self.prefix(of: baseName, maxByteCount: budget) + suffix
    }

    /// The longest whole-character prefix of `string` that fits in `maxByteCount` UTF-8 bytes.
    private static func prefix(of string: String, maxByteCount: Int) -> String {
        guard string.utf8.count > maxByteCount else { return string }

        var result = ""
        var byteCount = 0

        for character in string {
            let characterBytes = character.utf8.count
            guard byteCount + characterBytes <= maxByteCount else { break }
            result.append(character)
            byteCount += characterBytes
        }

        return result
    }

    /// The compact JSON suffix carrying endTime and color, or nil when there is nothing to encode.
    private var fileEncodingSuffix: String? {
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
              let data = try? JSONSerialization.data(withJSONObject: meta, options: .sortedKeys)
        else { return nil }

        return String(data: data, encoding: .utf8)
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
