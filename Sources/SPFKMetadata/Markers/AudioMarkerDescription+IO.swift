// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
internal import SPFKMetadataC

extension AudioMarkerDescription {
    /// From a WAV or AIFF marker, recovering end time and color from the name's JSON suffix.
    init(riffMarker marker: AudioMarker) {
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

    /// From a chapter whose format stores its own end time; the title's suffix supplies color only.
    init(chapterMarker marker: ChapterMarker) {
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
    ///
    /// - Parameter markerID: a WAV's cue ID; negative lets the writer pick a free one.
    func audioMarker(markerID: Int, fileType: AudioFileType?, fileSampleRate: Double? = nil) -> AudioMarker {
        let isAIFF = fileType == .aiff || fileType == .aifc

        return AudioMarker(
            name: isAIFF ? fileEncodedName(maxByteCount: Self.aiffMaxNameByteCount) : fileEncodedName,
            time: startTime,
            sampleRate: fileSampleRate ?? sampleRate ?? 0,
            markerID: Int32(markerID)
        )
    }

    /// For MP3 and Xiph, which store the end time natively. Read back by `init(chapterMarker:)`.
    var colorEncodedChapterMarker: ChapterMarker {
        ChapterMarker(name: colorEncodedName, startTime: startTime, endTime: endTime ?? startTime)
    }

    /// For MP4, whose chapters store neither end time nor color. Read back by
    /// `init(fileEncodedChapter:)`.
    var fileEncodedChapterMarker: ChapterMarker {
        ChapterMarker(name: fileEncodedName, startTime: startTime, endTime: endTime ?? startTime)
    }
}

// MARK: - JSON name encoding

extension AudioMarkerDescription {
    /// Millisecond precision.
    private static let durationDecimalPlaces = 3

    /// The name plus a JSON suffix of whichever of color and duration are set,
    /// `{"c":"RRGGBBAA","d":5.0}`, for formats with neither field. The plain name when neither is.
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
                // Serializes as "5.001", where a Double gives "5.001000000000000045".
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

    /// The name plus `{"c":"RRGGBBAA"}`, or the plain name when no color is set.
    public var colorEncodedName: String {
        let baseName = name ?? "Marker"
        guard let colorString = hexColor?.stringValue else { return baseName }

        let meta: [String: Any] = ["c": colorString]
        guard let data = try? JSONSerialization.data(withJSONObject: meta, options: .sortedKeys),
              let json = String(data: data, encoding: .utf8)
        else { return baseName }

        return "\(baseName) \(json)"
    }

    /// Splits a file-encoded name at its last `{`. When that text is not JSON (`"intro {part a}"`)
    /// the whole string is the name.
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
