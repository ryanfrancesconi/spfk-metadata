// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC

extension AudioMarkerDescriptionCollection {
    /// Reads the file's markers. Keep the cases in step with `MetaAudioFileDescription.saveMarkers()`,
    /// or markers are saved that can't be read back.
    public init(url: URL, fileType: AudioFileType? = nil) async throws {
        guard let fileType = fileType ?? AudioFileType(url: url) else {
            throw NSError(
                file: #file, function: #function,
                description: "Unable to determine file type from \(url.lastPathComponent)"
            )
        }

        switch fileType {
        case .m4a, .mp4, .aac, .m4b, .mov, .m4v:
            // AVFoundation covers files with neither a QuickTime nor a Nero chapter list.
            let rawChapters = MP4ChapterUtil.read(url.path) as? [ChapterMarker] ?? []
            if rawChapters.isNotEmpty {
                self = AudioMarkerDescriptionCollection(
                    markerDescriptions: rawChapters.map(AudioMarkerDescription.init(fileEncodedChapter:))
                )
            } else {
                let value: [ChapterMarker] = try await ChapterParser.parse(url: url)
                self = AudioMarkerDescriptionCollection(chapterMarkers: value)
            }

        case .ogg, .opus, .flac:
            // AVFoundation covers files without CHAPTER* fields.
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

    /// From WAV or AIFF markers.
    public init(audioMarkers value: [AudioMarker]) {
        self.init(
            markerDescriptions: value.map {
                AudioMarkerDescription(riffMarker: $0)
            })
    }

    /// From chapters whose format stores its own end time.
    public init(chapterMarkers value: [ChapterMarker]) {
        self.init(
            markerDescriptions: value.map {
                AudioMarkerDescription(chapterMarker: $0)
            })
    }

    /// For MP4: end time and color in each title's suffix.
    public var fileEncodedChapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.fileEncodedChapterMarker)
    }

    /// For MP3 and Xiph: color only in each title's suffix.
    public var colorEncodedChapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.colorEncodedChapterMarker)
    }
}
