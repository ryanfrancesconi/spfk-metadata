// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKBase
import SPFKMetadataC

/// ChapterParser, works with a variety of file types (m4a, mp4, flac, ogg).
/// Doesn't work with RIFF or MP3. Parse only, write isn't supported.
///
/// In particular this is the MP4 chapter parser in SPFKMetadata.
///
/// See MPEGChapterUtil.mm for writing mp3 chapters.
///
public enum ChapterParser {
    public static func parse(url: URL) async throws -> [ChapterMarker] {
        guard url.exists else {
            throw NSError(description: "Failed to open \(url.path)")
        }

        let asset = AVURLAsset(url: url)

        return try await parseChapters(asset: asset)
    }

    private static func parseChapters(asset: AVAsset) async throws -> [ChapterMarker] {
        let languages = try await asset.load(.availableChapterLocales).map(\.identifier)
        let timedGroups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: languages)

        var chapters = [ChapterMarker]()

        for i in 0 ..< timedGroups.count {
            let group = timedGroups[i]
            let cmStart = group.timeRange.start
            let cmEnd = group.timeRange.end

            let groupTitle = try? await title(from: group)
            let name = groupTitle ?? "Chapter \(i + 1)"

            chapters.append(
                ChapterMarker(
                    name: name,
                    startTime: cmStart.seconds,
                    endTime: cmEnd.seconds
                )
            )
        }

        return chapters
    }

    /// return the embedded title frame for this chapter
    private static func title(from group: AVTimedMetadataGroup) async throws -> String? {
        for item in group.items where item.commonKey == .commonKeyTitle {
            return try await item.load(.stringValue)
        }

        return nil
    }
}
