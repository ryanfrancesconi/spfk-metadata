// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

// swiftformat:disable consecutiveSpaces

/// RIFF INFO chunk tag identifiers (90+ cases) mapping camelCase names to four-character INFO keys
/// (e.g., `.title` → `"INAM"`, `.artist` → `"IART"`).
///
/// Conforms to ``TagFrameKey`` for shared lookup and display name logic.
/// Tags not mapped here are stored in ``TagData/customTags``.
public enum InfoFrameKey: String, TagFrameKey, Codable, Comparable {
    public static func < (lhs: InfoFrameKey, rhs: InfoFrameKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    case archivalLocation // Archival Location. Indicates where the subject of the file is archived
    case artist
    case baseURL
    case bpm // non standard frame
    case cinematographer
    case comment
    case commissioned
    case copyright
    case costumeDesigner
    case country
    case cropped
    case dateCreated
    case dateTimeOriginal
    case defaultAudioStream
    case dimensions
    case distributedBy
    case dotsPerInch
    case editedBy
    case eighthLanguage
    case encodedBy
    case endTimecode
    case engineer
    case fifthLanguage
    case firstLanguage
    case fourthLanguage
    case genre
    case keywords // Keywords. Provides a list of keywords that refer to the file or subject of the file. Separate multiple keywords with a semicolon and a blank. For example, "Seattle; aerial view; scenery".
    case language
    case language2
    case length
    case lightness // Lightness. Describes the changes in lightness settings on the digitizer required to produce the file. Note that the format of this information depends on hardware used.
    case location
    case logoURL
    case medium // Medium. Describes the original subject of the file, such as "computer image", "drawing", "lithograph", and so forth.
    case moreInfoBannerImage
    case moreInfoBannerURL
    case moreInfoText
    case moreInfoURL
    case musicBy
    case ninthLanguage
    case numberOfParts
    case numColors
    case organization
    case part
    case publisher // non standard
    case producedBy
    case product
    case productionDesigner
    case productionStudio
    case rate
    case rating
    case rippedBy
    case secondaryGenre
    case secondLanguage
    case seventhLanguage
    case sharpness
    case sixthLanguage
    case software
    case source // Source. Identifies the name of the person or organization who supplied the original subject of the file. For example, "Trey Research".
    case sourceForm
    case starring
    case starring2
    case startTimecode
    case statistics
    case subject
    case tapeName
    case technician
    case thirdLanguage
    case timeCode
    case title // Name. Stores the title of the subject of the file, such as "Seattle From Above".
    case trackNumber1
    case trackNumber2
    case trackNumber3 // IPRT, sometimes occurs, E.g, 9/13
    case url
    case vegasVersionMajor
    case vegasVersionMinor
    case version
    case watermarkURL
    case writtenBy
    case year

    public var value: String {
        switch self {
        case .archivalLocation:     "IARL"
        case .artist:               "IART"
        case .bpm:                  "IBPM"
        case .baseURL:              "IBSU"
        case .cinematographer:      "ICNM"
        case .comment:              "ICMT"
        case .commissioned:         "ICMS"
        case .copyright:            "ICOP"
        case .costumeDesigner:      "ICDS"
        case .country:              "ICNT"
        case .cropped:              "ICRP"
        case .dateCreated:          "ICRD"
        case .dateTimeOriginal:     "IDIT"
        case .defaultAudioStream:   "ICAS"
        case .dimensions:           "IDIM"
        case .distributedBy:        "IDST"
        case .dotsPerInch:          "IDPI"
        case .editedBy:             "IEDT"
        case .eighthLanguage:       "IAS8"
        case .encodedBy:            "IENC"
        case .endTimecode:          "TCDO"
        case .engineer:             "IENG" // TagKey.arranger
        case .fifthLanguage:        "IAS5"
        case .firstLanguage:        "IAS1"
        case .fourthLanguage:       "IAS4"
        case .genre:                "IGNR"
        case .keywords:             "IKEY"
        case .language:             "ILNG"
        case .language2:            "LANG"
        case .length:               "TLEN"
        case .lightness:            "ILGT"
        case .location:             "LOCA"
        case .logoURL:              "ILGU"
        case .medium:               "IMED"
        case .moreInfoBannerImage:  "IMBI"
        case .moreInfoBannerURL:    "IMBU"
        case .moreInfoText:         "IMIT"
        case .moreInfoURL:          "IMIU"
        case .musicBy:              "IMUS"
        case .ninthLanguage:        "IAS9"
        case .numberOfParts:        "PRT2"
        case .numColors:            "IPLT"
        case .organization:         "TORG"
        case .part:                 "PRT1"
        case .publisher:            "IPUB"
        case .producedBy:           "IPRO"
        case .product:              "IPRD" // TagKey.album
        case .productionDesigner:   "IPDS"
        case .productionStudio:     "ISTD"
        case .rate:                 "RATE"
        case .rating:               "IRTD"
        case .rippedBy:             "IRIP"
        case .secondaryGenre:       "ISGN"
        case .secondLanguage:       "IAS2"
        case .seventhLanguage:      "IAS7"
        case .sharpness:            "ISHP"
        case .sixthLanguage:        "IAS6"
        case .software:             "ISFT"
        case .source:               "ISRC"
        case .sourceForm:           "ISRF"
        case .starring:             "ISTR"
        case .starring2:            "STAR"
        case .startTimecode:        "TCOD"
        case .statistics:           "STAT" // (0: return Bad, 1: return OK)
        case .subject:              "ISBJ"
        case .tapeName:             "TAPE"
        case .technician:           "ITCH"
        case .thirdLanguage:        "IAS3"
        case .timeCode:             "ISMP" // SMPTE time code of digitization start point expressed as a NULL terminated text string "HH:MM:SS.FF". If performing MCI capture in AVICAP, this chunk will be automatically set based on the MCI start time.
        case .title:                "INAM"
        case .trackNumber1:         "ITRK" // ITRK acts as a metadata tag specifically for the track number, with IFRM often used for the total number of tracks (e.g., in 6/10 format).
        case .trackNumber2:         "TRCK"
        case .trackNumber3:         "IPRT"
        case .url:                  "TURL"
        case .vegasVersionMajor:    "VMAJ"
        case .vegasVersionMinor:    "VMIN"
        case .version:              "TVER"
        case .watermarkURL:         "IWMU"
        case .writtenBy:            "IWRI"
        case .year:                 "YEAR"
        }
    }
}

// swiftformat:enable consecutiveSpaces
