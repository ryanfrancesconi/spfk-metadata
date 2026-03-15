// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataC
import SPFKMetadataBase

extension AudioMarkerDescriptionCollection {
    /// Parses markers from the audio file at the given URL, dispatching to the appropriate parser
    /// based on file type: `ChapterParser` (m4a, mp4, flac, ogg), `MPEGChapterUtil` (mp3),
    /// or `AudioMarkerUtil` (aif, wav).
    public init(url: URL, fileType: AudioFileType? = nil) async throws {
        guard let fileType = fileType ?? AudioFileType(url: url) else {
            throw NSError(
                file: #file, function: #function,
                description: "Unable to determine file type from \(url.lastPathComponent)"
            )
        }

        switch fileType {
        case .m4a, .mp4, .ogg, .opus, .flac:
            let value: [ChapterMarker] = try await ChapterParser.parse(url: url)
            self = AudioMarkerDescriptionCollection(chapterMarkers: value)

        case .mp3:
            let value: [ChapterMarker] = MPEGChapterUtil.getChapters(url.path) as? [ChapterMarker] ?? []
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
        self.init(markerDescriptions: value.map {
            AudioMarkerDescription(riffMarker: $0)
        })
    }

    /// Creates a collection from ID3 or AVFoundation chapter markers.
    public init(chapterMarkers value: [ChapterMarker]) {
        self.init(markerDescriptions: value.map {
            AudioMarkerDescription(chapterMarker: $0)
        })
    }
}
