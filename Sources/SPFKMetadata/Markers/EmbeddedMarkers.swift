// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
import SPFKMetadataC

/// Writes and removes a file's markers without touching its tags.
///
/// `MetaAudioFileDescription.save(dirtyFlags: [.markers])` also rewrites the tags, so a caller
/// holding only markers would strip them going that way.
public enum EmbeddedMarkers {
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

        switch fileType {
        case .wav, .w64, .aiff, .aifc:
            // Cue points; endTime and color travel in the name suffix.
            let audioMarkers = descriptions.enumerated().map { i, desc in
                desc.audioMarker(markerID: i, fileType: fileType, fileSampleRate: fileSampleRate)
            }

            success = AudioMarkerUtil.write(audioMarkers, to: url)

        case .mp3:
            // ID3 CHAP frames carry endTime natively, so only the color is encoded into the title.
            success = MPEGChapterUtil.write(descriptions.map(\.colorEncodedChapterMarker), to: url.path)

        case .flac, .ogg, .opus:
            // Vorbis comment chapters; endTime is native here too.
            success = XiphChapterUtil.write(descriptions.map(\.colorEncodedChapterMarker), to: url.path)

        case .m4a, .mp4, .aac, .m4b, .mov, .m4v:
            // The QuickTime chapter track has neither an endTime nor a color field, so the title's
            // JSON suffix carries both. A bare `ChapterMarker` would demote every colored region
            // to an uncolored point marker.
            success = MP4ChapterUtil.write(descriptions.map(\.fileEncodedChapterMarker), to: url.path)

        default:
            throw MetadataError.unsupportedFormat(fileType, .markers)
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
        switch fileType {
        case .wav, .w64, .aiff, .aifc:
            AudioMarkerUtil.remove(url)

        case .mp3:
            MPEGChapterUtil.remove(url.path)

        case .flac, .ogg, .opus:
            XiphChapterUtil.remove(url.path)

        case .m4a, .mp4, .aac, .m4b, .mov, .m4v:
            MP4ChapterUtil.remove(url.path)

        default:
            throw MetadataError.unsupportedFormat(fileType, .markers)
        }
    }
}
