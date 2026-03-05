// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// Logical grouping of ``TagKey`` values for organizing tag display in UI (e.g., common, music, loudness).
public enum TagSet: CaseIterable, Hashable, Sendable {
    case common
    case music
    case loudness
    case replayGain
    case utility
    case other

    /// Human-readable section title for UI display.
    public var title: String {
        switch self {
        case .common: "Common Tags"
        case .music: "Music Tags"
        case .loudness: "Loudness"
        case .replayGain: "Replay Gain"
        case .utility: "Utility"
        case .other: "Other Tags"
        }
    }

    /// The ``TagKey`` values belonging to this set.
    public var keys: [TagKey] {
        switch self {
        case .other:
            TagSet.otherTags

        case .common:
            TagSet.commonTags

        case .music:
            TagSet.musicTags

        case .loudness:
            TagSet.loudnessTags

        case .replayGain:
            TagSet.replayGainTags

        case .utility:
            TagSet.utilityTags
        }
    }

    public init?(title: String) {
        for item in Self.allCases where item.title == title {
            self = item
            return
        }

        return nil
    }
}

extension TagSet {
    private static let otherTags: [TagKey] = TagKey.allCases.filter {
        !commonTags.contains($0) &&
            !musicTags.contains($0) &&
            !loudnessTags.contains($0) &&
            !replayGainTags.contains($0) &&
            !utilityTags.contains($0)
    }

    static let commonTags: [TagKey] = [
        .album,
        .artist,
        .comment,
        .date,
        .genre,
        .keywords,
        .mood,
        .title,
        .trackNumber,
    ]

    static let musicTags: [TagKey] = [
        .arranger,
        .bpm,
        .composer,
        .conductor,
        .initialKey,
        .instrumentation,
        .label,
        .lyrics,
        .movementName,
        .movementNumber,
        .remixer,
        .work
    ]

    static let loudnessTags: [TagKey] = [
        .loudnessRange,
        .loudnessIntegrated,
        .loudnessMaxMomentary,
        .loudnessMaxShortTerm,
        .loudnessTruePeak,
    ]

    static let replayGainTags: [TagKey] = [
        .replayGainAlbumGain,
        .replayGainAlbumPeak,
        .replayGainAlbumRange,
        .replayGainReferenceLoudness,
        .replayGainTrackGain,
        .replayGainTrackPeak,
        .replayGainTrackRange,
    ]

    static let utilityTags: [TagKey] = [
        .artistWebpage,
        .audioSourceWebpage,
        .fileWebpage,
        .isrc,
        .paymentWebpage,
        .publisherWebpage,
        .radioStationWebpage,
        .releaseDate,
        .taggingDate,
    ]

    static let sortTags: [TagKey] = [
        .albumArtistSort,
        .albumSort,
        .artistSort,
        .composerSort,
        .titleSort,
    ]
}
