// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata
// swiftformat:disable consecutiveSpaces

import Foundation
import OrderedCollections
import SPFKAudioBase
import SPFKBase
import SPFKUtils

/// Dictionary type mapping ``BEXTDescription/Key`` values to optional string representations.
public typealias BEXTKeyDictionary = OrderedDictionary<BEXTDescription.Key, String?>

extension BEXTDescription {
    /// Enumeration of BEXT chunk field identifiers for dictionary-style access via ``BEXTDescription/subscript(key:)``.
    public enum Key: Sendable, CaseIterable {
        case originator
        case originatorReference
        case originationDate
        case originationTime
        case timeReferenceSamples
        case timeReferenceString
        case umid
        case description
        case loudnessIntegrated
        case loudnessRange
        case maxTruePeakLevel
        case maxMomentaryLoudness
        case maxShortTermLoudness
        case version
        case codingHistory

        /// Whether this field can be edited by the user. Version and coding history are read-only.
        public var isEditable: Bool {
            self != .version &&
                self != .codingHistory
        }

        /// Human-readable label for UI display.
        public var displayName: String {
            switch self {
            case .originator:               "Originator"
            case .originatorReference:      "Originator Reference"
            case .originationDate:          "Origination Date"
            case .originationTime:          "Origination Time"
            case .timeReferenceSamples:     "Time Reference Samples"
            case .timeReferenceString:      "Time Reference"
            case .umid:                     "UMID"
            case .description:              "Description"
            case .loudnessIntegrated:       TagKey.loudnessIntegrated.displayName
            case .loudnessRange:            TagKey.loudnessRange.displayName
            case .maxTruePeakLevel:         TagKey.loudnessTruePeak.displayName
            case .maxMomentaryLoudness:     TagKey.loudnessMaxMomentary.displayName
            case .maxShortTermLoudness:     TagKey.loudnessMaxShortTerm.displayName
            case .version:                  "Version"
            case .codingHistory:            "Coding History"
            }
        }

        /// Detailed description of the field per the EBU Tech 3285 specification.
        public var description: String {
            switch self {
            case .originator:
                "Contains the name of the originator / producer of the audio file. (maximum 32 characters)"
            case .originatorReference:
                "Contains an unambiguous reference allocated by the originating organization."
            case .originationDate:
                "10 characters containing the date of creation of the audio sequence. The format shall be « ‘,year’,-,’month,’-‘,day,’» with 4 characters for the year and 2 characters per other item. Year is defined from 0000 to 9999 Month is defined from 1 to 12 Day is defined from 1 to 28, 29, 30 or 31 The separator between the items can be anything but it is recommended that one of the following characters be used: ‘-’  hyphen  ‘_’  underscore  ‘:’  colon  ‘ ’  space  ‘.’  stop."
            case .originationTime:
                "8 ASCII characters containing the time of creation of the audio sequence. The format shall be « ‘hour’-‘minute’-‘second’» with 2 characters per item. Hour is defined from 0 to 23. Minute and second are defined from 0 to 59. The separator between the items can be anything but it is recommended that one of the following characters be used: ‘-’  hyphen  ‘_’  underscore  ‘:’  colon  ‘ ’  space  ‘.’  stop."
            case .timeReferenceSamples:
                ""
            case .timeReferenceString:
                "These fields shall contain the time-code of the sequence. It is a 64-bit value which contains the first sample count since midnight. The number of samples per second depends on the sample frequency which is defined in the field <nSamplesPerSec> from the <format chunk>."
            case .umid:
                "Unique Material Identifier"
            case .description:
                "ASCII string (maximum 256 characters) containing a free description of the sequence. To help applications which display only a short description, it is recommended that a resume of the description is contained in the first 64 characters and the last 192 characters are used for details."
            case .loudnessIntegrated:
                TagKey.loudnessIntegrated.readableDescription ?? ""
            case .loudnessRange:
                TagKey.loudnessRange.readableDescription ?? ""
            case .maxTruePeakLevel:
                TagKey.loudnessTruePeak.readableDescription ?? ""
            case .maxMomentaryLoudness:
                TagKey.loudnessMaxMomentary.readableDescription ?? ""
            case .maxShortTermLoudness:
                TagKey.loudnessMaxShortTerm.readableDescription ?? ""
            case .version:
                "Version of the BWF"
            case .codingHistory:
                ""
            }
        }

        public init?(displayName: String) {
            for item in Self.allCases where item.displayName == displayName {
                self = item
                return
            }

            return nil
        }
    }
}

extension BEXTDescription {
    /// Gets or sets a BEXT field value by its ``Key``.
    public subscript(key: BEXTDescription.Key) -> String? {
        get {
            guard let value = dictionary[key] else { return nil }
            return value
        }

        set {
            dictionary[key] = newValue
        }
    }

    /// All BEXT fields as an ordered key-value dictionary. Setting this updates the underlying properties.
    public var dictionary: BEXTKeyDictionary {
        get { [
            .originator:            originator,
            .originatorReference:   originatorReference,
            .originationDate:       originationDate,
            .originationTime:       originationTime,
            .timeReferenceSamples:  timeReference?.string,
            .timeReferenceString:   timeReferenceString,
            .umid:                  umid,
            .description:           sequenceDescription,
            .loudnessIntegrated:    loudnessDescription.loudnessIntegrated?.string,
            .loudnessRange:         loudnessDescription.loudnessRange?.string,
            .maxTruePeakLevel:      loudnessDescription.maxTruePeakLevel?.string,
            .maxMomentaryLoudness:  loudnessDescription.maxMomentaryLoudness?.string,
            .maxShortTermLoudness:  loudnessDescription.maxShortTermLoudness?.string,
            .version:               version > 0 ? version.string : "",
            .codingHistory:         codingHistory,
        ] }

        set {
            if let value = newValue[.version], let unwrapped = value?.int16 {
                version = unwrapped
            }

            if let value = newValue[.originator] {
                originator = value
            }

            if let value = newValue[.originatorReference], let value {
                originatorReference = value
            }

            if let value = newValue[.originationDate], let value {
                originationDate = value
            }

            if let value = newValue[.originationTime], let value {
                originationTime = value
            }

            if let value = newValue[.umid], let value {
                umid = value
            }

            if let value = newValue[.description], let value {
                sequenceDescription = value
            }

            if let value = newValue[.loudnessIntegrated], let unwrapped = value?.double {
                loudnessDescription.loudnessIntegrated = unwrapped
            }

            if let value = newValue[.loudnessRange], let unwrapped = value?.double {
                loudnessDescription.loudnessRange = unwrapped
            }

            if let value = newValue[.maxTruePeakLevel], let unwrapped = value?.float {
                loudnessDescription.maxTruePeakLevel = unwrapped
            }

            if let value = newValue[.maxMomentaryLoudness], let unwrapped = value?.double {
                loudnessDescription.maxMomentaryLoudness = unwrapped
            }

            if let value = newValue[.maxShortTermLoudness], let unwrapped = value?.double {
                loudnessDescription.maxShortTermLoudness = unwrapped
            }

            if let value = newValue[.timeReferenceSamples], let unwrapped = value?.uInt64 {
                timeReference = unwrapped
            }

            if let value = newValue[.timeReferenceString], let value {
                Log.fault("TODO: timeReference (\(value)) isn't settable via the dictionary")
            }
        }
    }
}

// swiftformat:enable consecutiveSpaces
