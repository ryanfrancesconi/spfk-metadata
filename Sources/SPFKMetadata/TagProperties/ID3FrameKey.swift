// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

// swiftformat:disable consecutiveSpaces

/// ID3v2.4 frame identifiers (80+ cases) mapping camelCase names to four-character frame IDs
/// (e.g., `.title` → `"TIT2"`, `.artist` → `"TPE1"`).
///
/// Conforms to ``TagFrameKey`` for shared lookup and display name logic.
public enum ID3FrameKey: String, TagFrameKey, Codable, Comparable {
    public static func < (lhs: ID3FrameKey, rhs: ID3FrameKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

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
    case compilation            // Apple proprietary frame
    case composer
    case composerSort
    case conductor
    case copyright
    case copyrightUrl           // URL Frame
    case date                   // or year
    case discNumber
    case discSubtitle
    case encodedBy
    case encoding
    case encodingTime
    case fileWebpage            // URL Frame
    case fileType
    case genre
    case grouping               // Apple proprietary frame
    case initialKey
    case involvedPeopleList
    case isrc
    case label
    case language
    case length
    case lyricist
    case lyrics
    case media
    case mood
    case movementName           // Apple proprietary frame
    case movementNumber         // Apple proprietary frame
    case originalAlbum
    case originalArtist
    case originalDate
    case originalFilename
    case originalLyricist
    case owner
    case paymentWebpage         // URL Frame
    case picture
    case playlistDelay
    case podcast                // Apple proprietary frame
    case podcastCategory        // Apple proprietary frame
    case podcastDescription     // Apple proprietary frame
    case podcastId              // Apple proprietary frame
    case podcastURL             // Apple proprietary frame
    case `private`
    case producedNotice
    case publisherWebpage       // URL Frame
    case radioStation
    case radioStationOwner
    case radioStationWebpage    // URL Frame
    case releaseDate
    case remixer                // Could also be ARRANGER
    case subtitle
    case taggingDate
    case title
    case titleSort
    case trackNumber
    case work

    // MARK: Custom Tags

    case userDefined

    /// The associated ID3v2 label or TXXX if it is a non-standard `.userDefined` frame
    public var value: String {
        switch self {
        case .album:                "TALB"
        case .albumArtist:          "TPE2"
        case .albumArtistSort:      "TSO2"
        case .albumSort:            "TSOA"
        case .arranger, // AV uses arranger, TagLib uses remixer
             .remixer:              "TPE4"
        case .artist:               "TPE1"
        case .artistSort:           "TSOP"
        case .artistWebpage:        "WOAR"
        case .audioSourceWebpage:   "WOAS"
        case .bpm:                  "TBPM"
        case .comment:              "COMM"
        case .compilation:          "TCMP"
        case .composer:             "TCOM"
        case .composerSort:         "TSOC"
        case .conductor:            "TPE3"
        case .copyright:            "TCOP"
        case .copyrightUrl:         "WCOP"
        case .date:                 "TDRC"
        case .discNumber:           "TPOS"
        case .discSubtitle:         "TSST"
        case .encodedBy:            "TENC"
        case .encoding:             "TSSE"
        case .encodingTime:         "TDEN"
        case .fileWebpage:          "WOAF"
        case .fileType:             "TFLT"
        case .genre:                "TCON"
        case .grouping:             "GRP1"
        case .initialKey:           "TKEY"
        case .involvedPeopleList:   "TIPL"
        case .isrc:                 "TSRC"
        case .label:                "TPUB"
        case .language:             "TLAN"
        case .length:               "TLEN"
        case .lyricist:             "TEXT"
        case .lyrics:               "USLT"
        case .media:                "TMED"
        case .mood:                 "TMOO"
        case .movementName:         "MVNM"
        case .movementNumber:       "MVIN"
        case .originalAlbum:        "TOAL"
        case .originalArtist:       "TOPE"
        case .originalDate:         "TDOR"
        case .originalFilename:     "TOFN"
        case .originalLyricist:     "TOLY"
        case .owner:                "TOWN"
        case .picture:              "APIC"
        case .paymentWebpage:       "WPAY"
        case .playlistDelay:        "TDLY"
        case .podcast:              "PCST"
        case .podcastCategory:      "TCAT"
        case .podcastDescription:   "TDES"
        case .podcastId:            "TGID"
        case .podcastURL:           "WFED"
        case .private:              "PRIV"
        case .producedNotice:       "TPRO"
        case .publisherWebpage:     "WPUB"
        case .radioStation:         "TRSN"
        case .radioStationOwner:    "TRSO"
        case .radioStationWebpage:  "WORS"
        case .releaseDate:          "TDRL"
        case .subtitle:             "TIT3"
        case .taggingDate:          "TDTG"
        case .title:                "TIT2"
        case .titleSort:            "TSOT"
        case .trackNumber:          "TRCK"
        case .work:                 "TIT1"

        // MARK: Custom Tags
        case .userDefined:          "TXXX"
        }
    }
}

// swiftformat:enable consecutiveSpaces
