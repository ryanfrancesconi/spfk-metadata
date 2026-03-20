// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC

extension AudioMarkerDescriptionCollection {
    /// Parses markers from the audio file at the given URL, dispatching to the appropriate parser
    /// based on file type: `MP4ChapterUtil` (m4a, mp4, aac, m4b — QT chapter track with Nero chpl
    /// fallback, then AVFoundation), `ChapterParser` (flac, ogg, opus — AVFoundation),
    /// `MPEGChapterUtil` (mp3), or `AudioMarkerUtil` (aif, wav).
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
            // AVFoundation fallback for files with neither format.
            let chapters = MP4ChapterUtil.chapters(in: url.path) as? [ChapterMarker] ?? []
            if chapters.isNotEmpty {
                self = AudioMarkerDescriptionCollection(chapterMarkers: chapters)
            } else {
                let value: [ChapterMarker] = try await ChapterParser.parse(url: url)
                self = AudioMarkerDescriptionCollection(chapterMarkers: value)
            }

        case .ogg, .opus, .flac:
            let value: [ChapterMarker] = try await ChapterParser.parse(url: url)
            self = AudioMarkerDescriptionCollection(chapterMarkers: value)

        case .mp3:
            let value: [ChapterMarker] = MPEGChapterUtil.chapters(in: url.path) as? [ChapterMarker] ?? []
            self = AudioMarkerDescriptionCollection(chapterMarkers: value)

        case .aiff, .aifc, .wav, .w64:
            let value: [AudioMarker] = AudioMarkerUtil.getMarkers(url) as? [AudioMarker] ?? []
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
    /// via format-specific utilities (MP4, MPEG, Xiph).
    public var chapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.chapterMarker)
    }
}
