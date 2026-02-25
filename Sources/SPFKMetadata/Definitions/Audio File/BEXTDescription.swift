// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AudioToolbox
import Foundation
import OrderedCollections
import SPFKAudioBase
import SPFKMetadataC

/// BEXT Wave Chunk - BroadcastExtension. This is a wrapper to BEXTDescriptionC for swift
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
    /// 10 ASCII characters containing the date of creation of the audio sequence.
    /// The format shall be « ‘,year’,-,’month,’-‘,day,’» with 4 characters for the year
    /// and 2 characters per other item. 10 Tech 3285 v2 Broadcast Wave Format Specification
    /// Year is defined from 0000 to 9999 Month is defined from 1 to 12 Day is defined
    /// from 1 to 28, 29, 30 or 31 The separator between the items can be anything but
    /// it is recommended that one of the following characters be used:
    /// ‘-’  hyphen  ‘_’  underscore  ‘:’  colon  ‘ ’  space  ‘.’  stop
    public var originationDate: String?

    /// hh:mm:ss
    /// 8 ASCII characters containing the time of creation of the audio sequence. The format
    /// shall be « ‘hour’-‘minute’-‘second’» with 2 characters per item. Hour is defined
    /// from 0 to 23. Minute and second are defined from 0 to 59. The separator between
    /// the items can be anything but it is recommended that one of the following characters be used:
    /// ‘-’  hyphen  ‘_’  underscore  ‘:’  colon  ‘ ’  space  ‘.’  stop
    public var originationTime: String?

    /// Time reference in samples.
    ///
    /// These fields shall contain the time-code of the sequence. It is a 64-bit value which contains the first sample count since midnight.
    /// First sample count since midnight, low word (32 bits).
    ///
    /// Keep `UInt64` for larger headroom for invalid time values.
    public var timeReferenceLow: UInt64?

    /// Time reference in samples.
    /// First sample count since midnight, high word. The 32bit overflow is in the high value.
    ///
    /// Keep `UInt64` for larger headroom for invalid time values.
    public var timeReferenceHigh: UInt64?

    /// Combined 64bit time value of low and high words.
    ///
    /// Why split them?
    ///
    /// The BWF spec was created when many systems were still 32-bit.
    /// By splitting the value into two 32-bit fields, the file format
    /// ensures compatibility across older hardware and software that
    /// couldn't natively handle a single 64-bit "LongLong" integer.
    public var timeReference: UInt64? {
        get {
            guard let timeReferenceLow, let timeReferenceHigh else {
                return nil
            }

            return (UInt64(timeReferenceHigh) << 32) | UInt64(timeReferenceLow)
        }

        set {
            guard let newValue else {
                timeReferenceLow = nil
                timeReferenceHigh = nil
                return
            }

            timeReferenceLow = UInt64(newValue & 0xFFFF_FFFF)
            timeReferenceHigh = UInt64(newValue >> 32)
        }
    }

    /// Convenience time reference in seconds, requires sampleRate to be set.
    /// Sample rate isn't part of the BEXT values.
    public var timeReferenceInSeconds: TimeInterval? {
        guard let timeReference,
              let sampleRate,
              sampleRate > 0 else { return nil }
        return TimeInterval(timeReference) / sampleRate
    }

    /// Convenience time (00:00:00) reference in formatted time, requires sampleRate to be set.
    /// Sample rate isn't part of the BEXT values.
    public var timeReferenceString: String? {
        guard let timeReferenceInSeconds, !timeReferenceInSeconds.isNaN else { return nil }
        return RealTimeDomain.string(seconds: timeReferenceInSeconds, showHours: .enable)
    }

    /// (Note: Added in version 2.)
    public var loudnessDescription: LoudnessDescription = .init()

    /// Enables time convenience values via setting sampleRate
    public var sampleRate: Double?

    public init() {}

    public init?(url: URL) {
        guard let info = BEXTDescriptionC(path: url.path) else {
            return nil
        }

        self = BEXTDescription(info: info)
    }

    public init(info: BEXTDescriptionC) {
        version = info.version
        codingHistory = info.codingHistory
        sampleRate = info.sampleRate
        sequenceDescription = info.sequenceDescription
        originator = info.originator
        originationDate = info.originationDate
        originationTime = info.originationTime
        originatorReference = info.originatorReference
        timeReferenceLow = UInt64(info.timeReferenceLow)
        timeReferenceHigh = UInt64(info.timeReferenceHigh)

        if version >= 1 {
            umid = info.umid
        }

        if version >= 2 {
            loudnessDescription = .init(
                loudnessIntegrated: info.loudnessIntegrated,
                loudnessRange: info.loudnessRange,
                maxTruePeakLevel: info.maxTruePeakLevel,
                maxMomentaryLoudness: info.maxMomentaryLoudness,
                maxShortTermLoudness: info.maxShortTermLoudness
            ).validated()
        }
    }

    public init(dictionary: BEXTKeyDictionary) {
        self.dictionary = dictionary
    }

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

        if let value = timeReferenceLow, value == 0 {
            bext.timeReferenceLow = nil
        }

        if let value = timeReferenceHigh, value == 0 {
            bext.timeReferenceHigh = nil
        }

        bext.loudnessDescription = bext.loudnessDescription.validated()

        return bext
    }
}

extension BEXTDescription {
    /// Returns the objc representation for C portability
    public var bextDescriptionC: BEXTDescriptionC {
        let info = BEXTDescriptionC()

        func updateVersion(_ requiredVersion: Int16) {
            if info.version < requiredVersion {
                info.version = requiredVersion
            }
        }

        info.version = 0

        if let codingHistory {
            info.codingHistory = codingHistory
        }

        if let umid {
            updateVersion(1)
            info.umid = umid
        }

        if let loudnessIntegrated = loudnessDescription.loudnessIntegrated {
            updateVersion(2)
            info.loudnessIntegrated = loudnessIntegrated
        }

        if let loudnessRange = loudnessDescription.loudnessRange {
            updateVersion(2)
            info.loudnessRange = loudnessRange
        }

        if let maxTruePeakLevel = loudnessDescription.maxTruePeakLevel {
            updateVersion(2)
            info.maxTruePeakLevel = maxTruePeakLevel
        }

        if let maxMomentaryLoudness = loudnessDescription.maxMomentaryLoudness {
            updateVersion(2)
            info.maxMomentaryLoudness = maxMomentaryLoudness
        }

        if let maxShortTermLoudness = loudnessDescription.maxShortTermLoudness {
            updateVersion(2)
            info.maxShortTermLoudness = maxShortTermLoudness
        }

        if let sequenceDescription {
            info.sequenceDescription = sequenceDescription
        }

        if let originator {
            info.originator = originator
        }

        if let originationDate {
            info.originationDate = originationDate
        }

        if let originationTime {
            info.originationTime = originationTime
        }

        if let originatorReference {
            info.originatorReference = originatorReference
        }

        if let timeReferenceLow {
            info.timeReferenceLow = UInt32(timeReferenceLow)
        }

        if let timeReferenceHigh {
            info.timeReferenceHigh = UInt32(timeReferenceHigh)
        }

        return info
    }
}

extension BEXTDescription {
    /// Writes this BEXTDescription to file. The data will be validated before writing.
    public static func write(bextDescription: BEXTDescription, to url: URL) throws {
        let cObject = bextDescription.bextDescriptionC

        guard BEXTDescriptionC.write(cObject, path: url.path) else {
            throw NSError(description: "Failed to write BEXT chunk to \(url.path)")
        }
    }
}
