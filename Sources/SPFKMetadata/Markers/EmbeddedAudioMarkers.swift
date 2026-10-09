// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
internal import SPFKMetadataC

/// Writes and removes a file's markers without touching its tags.
///
/// On any file but a WAV, `MetaAudioFileDescription.save(dirtyFlags: [.markers])` also rewrites
/// the tags it read, so a caller holding only markers would strip them going that way.
public enum EmbeddedAudioMarkers {
    /// Writes `descriptions` in the order given, replacing the file's markers. An empty array
    /// leaves the file's markers in place; use ``removeAll(from:fileType:)`` to clear them.
    ///
    /// - Parameter fileSampleRate: converts a WAV or AIFF marker's time to a frame position; nil
    ///   uses the marker's own sample rate.
    public static func write(
        _ descriptions: [AudioMarkerDescription],
        to url: URL,
        fileType: AudioFileType,
        fileSampleRate: Double? = nil
    ) throws {
        let success: Bool

        switch fileType.markerStorage {
        case .riffCues, .aiffMarks, .coreAudio:
            // Cue points; endTime and color travel in the name suffix.
            let audioMarkers = descriptions.map { desc in
                desc.audioMarker(markerID: desc.markerID ?? -1, fileType: fileType, fileSampleRate: fileSampleRate)
            }

            success = AudioMarkerUtil.write(audioMarkers, to: url)

        case .id3Chapters:
            // ID3 CHAP frames carry endTime natively, so only the color is encoded into the title.
            success = MPEGChapterUtil.write(descriptions.map(\.colorEncodedChapterMarker), to: url.path)

        case .xiphChapters:
            // Vorbis comment chapters; endTime is native here too.
            success = XiphChapterUtil.write(descriptions.map(\.colorEncodedChapterMarker), to: url.path)

        case .mp4Chapters:
            // The QuickTime chapter track has neither an endTime nor a color field, so the title's
            // JSON suffix carries both. A bare `ChapterMarker` would demote every colored region
            // to an uncolored point marker.
            success = MP4ChapterUtil.write(descriptions.map(\.fileEncodedChapterMarker), to: url.path)

        case nil:
            throw MetadataError.unsupportedFormat(fileType.utType, .markers)
        }

        guard success else {
            throw MetadataError.writeFailed(.markers, url)
        }
    }

    /// Removes every marker from the file.
    ///
    /// - Returns: whether anything was removed. `false` also covers a file that had none, so it
    ///   is not an error signal.
    @discardableResult
    public static func removeAll(from url: URL, fileType: AudioFileType) throws -> Bool {
        switch fileType.markerStorage {
        case .riffCues, .aiffMarks, .coreAudio:
            AudioMarkerUtil.remove(url)

        case .id3Chapters:
            MPEGChapterUtil.remove(url.path)

        case .xiphChapters:
            XiphChapterUtil.remove(url.path)

        case .mp4Chapters:
            MP4ChapterUtil.remove(url.path)

        case nil:
            throw MetadataError.unsupportedFormat(fileType.utType, .markers)
        }
    }
}
