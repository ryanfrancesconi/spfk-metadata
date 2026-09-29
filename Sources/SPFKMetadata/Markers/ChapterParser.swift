// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC

/// Reads chapters through AVFoundation, which cannot write them. The fallback for the MP4 and Xiph
/// families when TagLib finds none.
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

    private static func title(from group: AVTimedMetadataGroup) async throws -> String? {
        for item in group.items where item.commonKey == .commonKeyTitle {
            return try await item.load(.stringValue)
        }

        return nil
    }
}
