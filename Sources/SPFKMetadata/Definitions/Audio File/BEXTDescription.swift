// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AudioToolbox
import Foundation
import OrderedCollections
import SPFKAudioBase

/// Broadcast Wave Extension (BWF/BEXT) chunk metadata for WAV files.
///
/// Wraps the EBU Tech 3285 BEXT data in a Swift-native type with support for v0, v1 (UMID),
/// and v2 (loudness) fields. Use ``validated()`` to sanitize placeholder values before display.
public struct BEXTDescription: Hashable, Sendable {
    /// BWF Version 0, 1, or 2. This will be set based on the content provided.
    public var version: Int16 = 0

    /// A free description of the sequence.
    /// To help applications which display only a short description, it is recommended
    /// that a resume of the description is contained in the first 64 characters
    /// and the last 192 characters are used for details.
    ///
    /// (Note: this isn't named "description" for compatibility with CoreData/SwiftData Schemas)
    public var sequenceDescription: String?

    /// UMID (Unique Material Identifier) to standard SMPTE. (Note: Added in version 1.)
    public var umid: String?

    /// A <CodingHistory> field is provided in the BWF format to allow the exchange of information on previous signal processing,
    /// IE: A=PCM,F=48000,W=16,M=stereo|mono,T=original
    ///
    /// A=<ANALOGUE, PCM, MPEG1L1, MPEG1L2, MPEG1L3, MPEG2L1, MPEG2L2, MPEG2L3>
    /// F=<11000,22050,24000,32000,44100,48000>
    /// B=<any bit-rate allowed in MPEG 2 (ISO/IEC 13818-3)>
    /// W=<8, 12, 14, 16, 18, 20, 22, 24>
    /// M=<mono, stereo, dual-mono, joint-stereo>
    /// T=<a free ASCII-text string for in house use. This string should contain no commas (ASCII 2Chex).
    /// Examples of the contents: ID-No; codec type; A/D type>
    public var codingHistory: String?

    /// The name of the originator / producer of the audio file
    public var originator: String?

    /// Unambiguous reference allocated by the originating organization
    public var originatorReference: String?

    /// yyyy-mm-dd
    ///
    /// 10 ASCII characters containing the date of creation of the audio sequence.
    /// The format shall be « ‘,year’,-,’month,’-‘,day,’» with 4 characters for the year
    /// and 2 characters per other item. 10 Tech 3285 v2 Broadcast Wave Format Specification
    /// Year is defined from 0000 to 9999 Month is defined from 1 to 12 Day is defined
    /// from 1 to 28, 29, 30 or 31 The separator between the items can be anything but
    /// it is recommended that one of the following characters be used:
    /// ‘-’  hyphen  ‘_’  underscore  ‘:’  colon  ‘ ’  space  ‘.’  stop
    public var originationDate: String?

    /// hh:mm:ss
    ///
    /// 8 ASCII characters containing the time of creation of the audio sequence. The format
    /// shall be « ‘hour’-‘minute’-‘second’» with 2 characters per item. Hour is defined
    /// from 0 to 23. Minute and second are defined from 0 to 59. The separator between
    /// the items can be anything but it is recommended that one of the following characters be used:
    /// ‘-’  hyphen  ‘_’  underscore  ‘:’  colon  ‘ ’  space  ‘.’  stop
    public var originationTime: String?

    /// Time reference in samples.
    ///
    /// First sample count since midnight, low word (32 bits).
    ///
    /// Note: uses `UInt64` for larger headroom for invalid time values.
    public var timeReferenceLow: UInt64?

    /// Time reference in samples.
    /// First sample count since midnight, high word.
    /// The 32bit overflow is in the high value.
    ///
    /// Note: uses `UInt64` for larger headroom for invalid time values.
    public var timeReferenceHigh: UInt64?

    /// Combined 64bit time value of low and high words.
    ///
    /// The BWF spec was created when many systems were still 32-bit.
    /// By splitting the value into two 32-bit fields, the file format
    /// ensures compatibility across older hardware and software that
    /// couldn't natively handle a single 64-bit "LongLong" integer.
    public var timeReference: UInt64? {
        get {
            guard let timeReferenceLow, let timeReferenceHigh else { return nil }

            return (timeReferenceHigh << 32) | timeReferenceLow
        }

        set {
            guard let newValue else {
                timeReferenceLow = nil
                timeReferenceHigh = nil
                return
            }

            // Mask the top 32 bits (0xFFFFFFFF) to isolate the lower half
            timeReferenceLow = newValue & 0xFFFF_FFFF

            // Shift right by 32 bits to move upper bits to lower position
            timeReferenceHigh = newValue >> 32
        }
    }

    /// Convenience time reference in seconds, requires sampleRate to be set.
    /// Sample rate isn't part of the BEXT values.
    public var timeReferenceInSeconds: TimeInterval? {
        guard let timeReference,
              let sampleRate, sampleRate > 0
        else { return nil }

        return TimeInterval(timeReference) / sampleRate
    }

    /// Convenience time (00:00:00) reference in formatted time, requires sampleRate to be set.
    /// Sample rate isn't part of the BEXT values.
    public var timeReferenceString: String? {
        guard let timeReferenceInSeconds, !timeReferenceInSeconds.isNaN else { return nil }
        return RealTimeDomain.string(seconds: timeReferenceInSeconds, showHours: .enable)
    }

    /// EBU R128 loudness values (integrated, range, true peak, momentary, short-term).
    /// Only populated when ``version`` >= 2.
    public var loudnessDescription: LoudnessDescription = .init()

    /// Sample rate used to convert ``timeReference`` (samples) to seconds.
    /// Not part of the BEXT chunk itself — set externally from the audio format.
    public var sampleRate: Double?

    public init() {}

    /// Creates a `BEXTDescription` from a key-value dictionary of BEXT fields.
    public init(dictionary: BEXTKeyDictionary) {
        self.dictionary = dictionary
    }

    /// Returns a copy with placeholder values sanitized (all-zero UMID, dates, and time references cleared).
    public func validated() -> BEXTDescription {
        var bext = self

        if let value = bext.umid, value.first == "0", value.allElementsAreEqual {
            bext.umid = ""
        }

        if let value = bext.originationDate, value.first == "0", value.allElementsAreEqual {
            bext.originationDate = ""
        }

        if let value = bext.originationTime, value.first == "0", value.allElementsAreEqual {
            bext.originationTime = ""
        }

        // Only clear time reference if both low and high are zero.
        // A low of 0 with non-zero high is a valid 64-bit time value.
        if bext.timeReferenceLow == 0, bext.timeReferenceHigh == 0 {
            bext.timeReferenceLow = nil
            bext.timeReferenceHigh = nil
        }

        bext.loudnessDescription = bext.loudnessDescription.validated()

        return bext
    }
}
