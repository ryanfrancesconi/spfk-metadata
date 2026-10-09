// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
internal import SPFKMetadataC

extension AudioMarkerDescriptionCollection {
    /// Reads the file's markers from its ``AudioFileType/markerStorage``, the same table every
    /// writer dispatches on. Empty when the file has none; throws `MetadataError.readFailed` when
    /// the reader can't open it.
    public init(url: URL, fileType: AudioFileType? = nil) async throws {
        guard let fileType = fileType ?? AudioFileType(url: url) else {
            throw MetadataError.unsupportedFormat(nil, .markers)
        }

        switch fileType.markerStorage {
        case .mp4Chapters:
            // AVFoundation covers files with neither a QuickTime nor a Nero chapter list.
            let rawChapters: [ChapterMarker] = try Self.read(MP4ChapterUtil.read(url.path), url: url)
            if rawChapters.isNotEmpty {
                self = AudioMarkerDescriptionCollection(
                    markerDescriptions: rawChapters.map(AudioMarkerDescription.init(fileEncodedChapter:))
                )
            } else {
                self = await AudioMarkerDescriptionCollection(chapterMarkers: Self.avFoundationChapters(url: url))
            }

        case .xiphChapters:
            // AVFoundation covers files without CHAPTER* fields.
            let xiph: [ChapterMarker] = try Self.read(XiphChapterUtil.read(url.path), url: url)
            if xiph.isNotEmpty {
                self = AudioMarkerDescriptionCollection(chapterMarkers: xiph)
            } else {
                self = await AudioMarkerDescriptionCollection(chapterMarkers: Self.avFoundationChapters(url: url))
            }

        case .id3Chapters:
            let value: [ChapterMarker] = try Self.read(MPEGChapterUtil.read(url.path), url: url)
            self = AudioMarkerDescriptionCollection(chapterMarkers: value)

        case .riffCues, .aiffMarks, .coreAudio:
            let value: [AudioMarker] = try Self.read(AudioMarkerUtil.read(url), url: url)
            self = AudioMarkerDescriptionCollection(audioMarkers: value)

        case nil:
            throw MetadataError.unsupportedFormat(fileType, .markers)
        }
    }

    /// A reader's result: nil when it could not open the file, empty when the file has no markers.
    private static func read<T>(_ value: [Any]?, url: URL) throws -> [T] {
        guard let value else { throw MetadataError.readFailed(.markers, url) }
        return value.compactMap { $0 as? T }
    }

    /// Chapters only AVFoundation sees, for a file TagLib opened and found none in. AVFoundation
    /// opens fewer containers than TagLib (not Ogg), so its failure means there are none to read.
    private static func avFoundationChapters(url: URL) async -> [ChapterMarker] {
        do {
            return try await ChapterParser.parse(url: url)
        } catch {
            return []
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
