// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
internal import SPFKMetadataC

extension AudioMarkerDescriptionCollection {
    /// Reads the file's markers from its ``AudioFileType/markerStorage``, the same table every
    /// writer dispatches on.
    public init(url: URL, fileType: AudioFileType? = nil) async throws {
        guard let fileType = fileType ?? AudioFileType(url: url) else {
            throw MetadataError.unsupportedFormat(nil, .markers)
        }

        switch fileType.markerStorage {
        case .mp4Chapters:
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

        case .xiphChapters:
            // AVFoundation covers files without CHAPTER* fields.
            let xiph: [ChapterMarker] = XiphChapterUtil.read(url.path) as? [ChapterMarker] ?? []
            if xiph.isNotEmpty {
                self = AudioMarkerDescriptionCollection(chapterMarkers: xiph)
            } else {
                let value: [ChapterMarker] = try await ChapterParser.parse(url: url)
                self = AudioMarkerDescriptionCollection(chapterMarkers: value)
            }

        case .id3Chapters:
            let value: [ChapterMarker] = MPEGChapterUtil.read(url.path) as? [ChapterMarker] ?? []
            self = AudioMarkerDescriptionCollection(chapterMarkers: value)

        case .riffCues, .aiffMarks, .coreAudio:
            let value: [AudioMarker] = AudioMarkerUtil.read(url) as? [AudioMarker] ?? []
            self = AudioMarkerDescriptionCollection(audioMarkers: value)

        case nil:
            throw MetadataError.unsupportedFormat(fileType, .markers)
        }
    }

    /// From WAV or AIFF markers.
    init(audioMarkers value: [AudioMarker]) {
        self.init(
            markerDescriptions: value.map {
                AudioMarkerDescription(riffMarker: $0)
            })
    }

    /// From chapters whose format stores its own end time.
    init(chapterMarkers value: [ChapterMarker]) {
        self.init(
            markerDescriptions: value.map {
                AudioMarkerDescription(chapterMarker: $0)
            })
    }

    /// For MP4: end time and color in each title's suffix.
    var fileEncodedChapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.fileEncodedChapterMarker)
    }

    /// For MP3 and Xiph: color only in each title's suffix.
    var colorEncodedChapterMarkers: [ChapterMarker] {
        markerDescriptions.map(\.colorEncodedChapterMarker)
    }
}
