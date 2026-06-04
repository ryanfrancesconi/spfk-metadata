// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC

extension AudioMarkerDescriptionCollection {
    /// Parses markers from the audio file at the given URL, dispatching to the appropriate parser
    /// based on file type: `MP4ChapterUtil` (m4a, mp4, aac, m4b — QT chapter track with Nero chpl
    /// fallback, then AVFoundation), `XiphChapterUtil` (flac, ogg, opus — VorbisComment chapter
    /// fields with `ChapterParser` AVFoundation fallback), `MPEGChapterUtil` (mp3),
    /// or `AudioMarkerUtil` (aif, wav).
    public init(url: URL, fileType: AudioFileType? = nil) async throws {
        guard let fileType = fileType ?? AudioFileType(url: url) else {
            throw NSError(
                file: #file, function: #function,
                description: "Unable to determine file type from \(url.lastPathComponent)"
            )
        }

        switch fileType {
        case .m4a, .mp4, .aac, .m4b:
            // MP4ChapterUtil reads QT chapter track first, then Nero chpl fallback.
            // Chapter titles may carry a JSON metadata suffix written by ShadowTag;
            // decode names to recover endTime, color, and markerType.
            // AVFoundation fallback for files with neither chapter format.
            let rawChapters = MP4ChapterUtil.read(url.path) as? [ChapterMarker] ?? []
            if rawChapters.isNotEmpty {
                let descriptions = rawChapters.map { chapter -> AudioMarkerDescription in
                    let (name, duration, hexColor) = AudioMarkerDescription.decodeFileName(chapter.name ?? "")
                    return AudioMarkerDescription(
                        name: name.isEmpty ? nil : name,
                        startTime: chapter.startTime,
                        endTime: duration.map { chapter.startTime + $0 },
                        hexColor: hexColor,
                        markerType: duration != nil ? .region : .cue
                    )
                }
                self = AudioMarkerDescriptionCollection(markerDescriptions: descriptions)
            } else {
                let value: [ChapterMarker] = try await ChapterParser.parse(url: url)
                self = AudioMarkerDescriptionCollection(chapterMarkers: value)
            }

        case .ogg, .opus, .flac:
            // XiphChapterUtil reads VorbisComment CHAPTER* fields and preserves
            // CHAPTER000END endTime for segment markers. Fall back to AVFoundation
            // ChapterParser for files without VorbisComment chapter fields.
            let xiph: [ChapterMarker] = XiphChapterUtil.read(url.path) as? [ChapterMarker] ?? []
            if xiph.isNotEmpty {
                self = AudioMarkerDescriptionCollection(chapterMarkers: xiph)
            } else {
                let value: [ChapterMarker] = try await ChapterParser.parse(url: url)
                self = AudioMarkerDescriptionCollection(chapterMarkers: value)
            }

        case .mp3:
            let value: [ChapterMarker] = MPEGChapterUtil.read(url.path) as? [ChapterMarker] ?? []
            self = AudioMarkerDescriptionCollection(chapterMarkers: value)

        case .aiff, .aifc, .wav, .w64:
            let value: [AudioMarker] = AudioMarkerUtil.read(url) as? [AudioMarker] ?? []
            self = AudioMarkerDescriptionCollection(audioMarkers: value)

        default:
            throw NSError(
                file: #file, function: #function, description: "Unsupported file type: \(url.lastPathComponent)"
            )
        }
    }

    /// Creates a collection from Core Audio RIFF markers.
    public init(audioMarkers value: [AudioMarker]) {
        self.init(
            markerDescriptions: value.map {
                AudioMarkerDescription(riffMarker: $0)
            })
    }

    /// Creates a collection from ID3 or AVFoundation chapter markers.
    public init(chapterMarkers value: [ChapterMarker]) {
        self.init(
            markerDescriptions: value.map {
                AudioMarkerDescription(chapterMarker: $0)
            })
    }

    /// Converts the stored marker descriptions to `ChapterMarker` objects for writing
    /// via format-specific utilities (MPEG, Xiph).
    public var chapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.chapterMarker)
    }

    /// Converts the stored marker descriptions to `ChapterMarker` objects with JSON metadata
    /// suffixes in the title, for writing to MP4 (which has no native endTime or color fields).
    public var fileEncodedChapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.fileEncodedChapterMarker)
    }

    /// Converts the stored marker descriptions to `ChapterMarker` objects with a color-only
    /// JSON suffix in the title, for writing to MP3 and Xiph (FLAC/OGG/Opus) formats.
    /// These formats store endTime natively, so only color needs to be embedded in the title.
    public var colorEncodedChapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.colorEncodedChapterMarker)
    }
}
