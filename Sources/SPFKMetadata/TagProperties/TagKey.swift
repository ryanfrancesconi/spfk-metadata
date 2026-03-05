// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata
// swiftformat:disable consecutiveSpaces

import Foundation
import SPFKBase

/// Canonical tag key enum with 100+ cases covering ID3v2, RIFF INFO, and custom TXXX frames.
///
/// Serves as the unified key type for reading and writing audio metadata across all supported formats.
/// Each case maps to both an ``ID3FrameKey`` (e.g., `TIT2`) and, where applicable, an ``InfoFrameKey``
/// (e.g., `INAM`). Tags that don't match any case are stored as custom tags keyed by their raw string.
///
/// Supports lookup by ``taglibKey`` (uppercase), ``displayName`` (title-cased), ``id3Frame``, and ``infoFrame``.
public enum TagKey: String, CaseIterable, Codable, Comparable, Sendable {
    public static func < (lhs: TagKey, rhs: TagKey) -> Bool {
        lhs.rawValue.standardCompare(with: rhs.rawValue)
    }

    /// The album of the song
    case album
    case albumArtist            // id3's spec says 'PERFORMER', but most programs use 'ALBUMARTIST'
    case albumArtistSort        // Apple proprietary frame
    case albumSort
    case arranger
    case artist
    case artistSort
    case artistWebpage          // URL Frame
    case audioSourceWebpage     // URL Frame
    case bpm
    case comment
    case compilation
    case composer
    case composerSort
    case conductor
    case copyright
    case copyrightURL           // URL Frame
    case date                   // or year
    case discNumber
    case discSubtitle
    case encodedBy
    case encoding
    case encodingTime
    case endTimecode            // TXXX RIFF INFO
    case fileType
    case fileWebpage            // URL Frame
    case genre
    case grouping
    case initialKey
    case instrumentation        // TXXX non standard id3
    case involvedPeopleList
    case isrc
    case keywords               // TXXX RIFF INFO non standard id3
    case label
    case language
    case length
    case lyricist
    case lyrics
    case media
    case mood
    case movementName
    case movementNumber
    case originalAlbum
    case originalArtist
    case originalDate
    case originalFilename
    case originalLyricist
    case owner
    case paymentWebpage         // URL Frame
    case performer              // TXXX RIFF INFO
    case playlistDelay
    case podcast                // Apple proprietary frame
    case podcastCategory        // Apple proprietary frame
    case podcastDescription     // Apple proprietary frame
    case podcastId              // Apple proprietary frame
    case podcastKeywords        // TXXX Apple proprietary frame
    case podcastURL             // Apple proprietary frame
    case producedNotice
    case publisherWebpage       // URL Frame
    case radioStation
    case radioStationOwner
    case radioStationWebpage    // URL Frame
    case releaseCountry         // RIFF INFO
    case releaseDate
    case remixer                // Could also be ARRANGER
    case startTimecode          // TXXX RIFF INFO
    case subtitle
    case taggingDate
    case title
    case titleSort
    case trackNumber
    case work

    // MARK: TXXX Non-Standard packageDefined frames

    // TXXX Loudness Tags. Defined by SPFKMetadata. These are present in BEXT chunks but missing in standard ID3.

    case loudnessIntegrated
    case loudnessRange
    case loudnessTruePeak
    case loudnessMaxMomentary
    case loudnessMaxShortTerm

    // Replay Gain. Proposed ID3 addition. Some adoptance.

    case replayGainTrackGain
    case replayGainTrackPeak
    case replayGainTrackRange
    case replayGainAlbumGain
    case replayGainAlbumPeak
    case replayGainAlbumRange
    case replayGainReferenceLoudness
}

// MARK: - overrides

extension TagKey {
    /// All `TagKey` cases that map to the TXXX user-defined ID3 frame.
    public static let userDefinedKeys: [TagKey] =
        allCases.filter {
            $0.id3Frame == .userDefined
        }

    /// User facing string value for the tag.
    ///
    /// e.g., `.trackNumber` = "Track Number"
    public var displayName: String {
        switch self {
        case .copyrightURL:         "Copyright URL"
        case .podcastURL:           "Podcast URL"
        case .isrc:                 "ISRC"
        case .loudnessIntegrated:   "Loudness Integrated (LUFS)"
        case .loudnessRange:        "Loudness Range (LRA)"
        case .loudnessTruePeak:     "Loudness True Peak (dBTP)"
        case .loudnessMaxMomentary: "Loudness Max Momentary (LUFS)"
        case .loudnessMaxShortTerm: "Loudness Max Short-Term (LUFS)"

        //
        default:
            // This works for any standard camelCase rawValue
            rawValue.spacedTitleCased
        }
    }

    /// The uppercase property key used by TagLib (e.g., `"TITLE"`, `"REPLAYGAIN_TRACK_GAIN"`).
    /// Most cases are the uppercased `rawValue`; overrides handle non-standard key formats.
    public var taglibKey: String {
        switch self {
        case .replayGainTrackGain:          "REPLAYGAIN_TRACK_GAIN"
        case .replayGainTrackPeak:          "REPLAYGAIN_TRACK_PEAK"
        case .replayGainTrackRange:         "REPLAYGAIN_TRACK_RANGE"
        case .replayGainAlbumGain:          "REPLAYGAIN_ALBUM_GAIN"
        case .replayGainAlbumPeak:          "REPLAYGAIN_ALBUM_PEAK"
        case .replayGainAlbumRange:         "REPLAYGAIN_ALBUM_RANGE"
        case .replayGainReferenceLoudness:  "REPLAYGAIN_REFERENCE_LOUDNESS"
        default:
            // This works for most of the keys as it was planned that way
            rawValue.uppercased()
        }
    }
}

// swiftformat:enable consecutiveSpaces
