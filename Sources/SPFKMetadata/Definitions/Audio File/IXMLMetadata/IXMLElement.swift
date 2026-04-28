// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

@preconcurrency import AEXML
import Foundation

/// Element names used in the iXML (BWFXML) chunk specification.
///
/// Each case maps to the uppercase XML element name as it appears in the iXML spec.
/// Use the `AEXMLElement` subscript extension for type-safe element access.
///
/// Reference: http://www.gallery.co.uk/ixml/
public enum IXMLElement: String, Sendable {
    // MARK: - Root

    case bwfxml = "BWFXML"

    // MARK: - Top-Level Elements

    case ixmlVersion = "IXML_VERSION"
    case project = "PROJECT"
    case scene = "SCENE"
    case take = "TAKE"
    case tape = "TAPE"
    case familyUID = "FAMILY_UID"
    case familyName = "FAMILY_NAME"
    case fileUID = "FILE_UID"
    case note = "NOTE"
    case circled = "CIRCLED"
    case wildTrack = "WILD_TRACK"

    // MARK: - SPEED Container

    case speed = "SPEED"
    case masterSpeed = "MASTER_SPEED"
    case currentSpeed = "CURRENT_SPEED"
    case timecodeRate = "TIMECODE_RATE"
    case timecodeFlag = "TIMECODE_FLAG"
    case fileSampleRate = "FILE_SAMPLE_RATE"
    case audioBitDepth = "AUDIO_BIT_DEPTH"
    case digitizerSampleRate = "DIGITIZER_SAMPLE_RATE"
    case timestampSamplesSinceMidnightHi = "TIMESTAMP_SAMPLES_SINCE_MIDNIGHT_HI"
    case timestampSamplesSinceMidnightLo = "TIMESTAMP_SAMPLES_SINCE_MIDNIGHT_LO"
    case timestampSampleRate = "TIMESTAMP_SAMPLE_RATE"

    // MARK: - TRACK_LIST Container

    case trackList = "TRACK_LIST"
    case trackCount = "TRACK_COUNT"
    case track = "TRACK"
    case channelIndex = "CHANNEL_INDEX"
    case interleaveIndex = "INTERLEAVE_INDEX"
    case name = "NAME"
    case function = "FUNCTION"

    // MARK: - BEXT Container (mirrors BWF BEXT chunk)

    case bext = "BEXT"
    case bextVersion = "BWF_VERSION"
    case bextDescription = "BWF_DESCRIPTION"
    case bextOriginator = "BWF_ORIGINATOR"
    case bextOriginatorReference = "BWF_ORIGINATOR_REFERENCE"
    case bextOriginationDate = "BWF_ORIGINATION_DATE"
    case bextOriginationTime = "BWF_ORIGINATION_TIME"
    case bextTimeReferenceLow = "BWF_TIME_REFERENCE_LOW"
    case bextTimeReferenceHigh = "BWF_TIME_REFERENCE_HIGH"
    case bextCodingHistory = "BWF_CODING_HISTORY"
    case bextUMID = "BWF_UMID"

    // MARK: - LOUDNESS Container

    case loudness = "LOUDNESS"
    case loudnessValue = "LOUDNESS_VALUE"
    case loudnessRange = "LOUDNESS_RANGE"
    case maxTruePeakLevel = "MAX_TRUE_PEAK_LEVEL"
    case maxMomentary = "MAX_MOMENTARY"
    case maxShortTerm = "MAX_SHORT_TERM"

    // MARK: - HISTORY Container

    case history = "HISTORY"
    case originalFilename = "ORIGINAL_FILENAME"
    case parentFilename = "PARENT_FILENAME"
    case parentUID = "PARENT_UID"

    // MARK: - SYNC_POINT_LIST Container

    case syncPointList = "SYNC_POINT_LIST"
    case syncPointCount = "SYNC_POINT_COUNT"
    case syncPoint = "SYNC_POINT"
    case syncPointType = "SYNC_POINT_TYPE"
    case syncPointFunction = "SYNC_POINT_FUNCTION"
    case syncPointComment = "SYNC_POINT_COMMENT"
    case syncPointLow = "SYNC_POINT_LOW"
    case syncPointHigh = "SYNC_POINT_HIGH"

    // MARK: - USER Container

    case user = "USER"

    // MARK: - ASWG Container (Audio Services Working Group)
    // Child element names use camelCase per the ASWG spec (not UPPERCASE_UNDERSCORE).

    case aswg = "ASWG"

    // MARK: - STEINBERG Container

    case steinberg = "STEINBERG"

    // MARK: - LOCATION Container

    case location = "LOCATION"
    case locationGPS = "GPS"
    case locationAltitude = "ALTITUDE"
    case locationTime = "TIME"
}

extension AEXMLElement {
    /// Type-safe subscript for iXML element access.
    public subscript(key: IXMLElement) -> AEXMLElement? {
        let value = self[key.rawValue]
        guard value.error == nil else { return nil }
        return value
    }
}
