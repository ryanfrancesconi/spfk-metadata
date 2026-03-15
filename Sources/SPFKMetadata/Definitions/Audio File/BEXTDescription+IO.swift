// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataC
import SPFKMetadataBase

extension BEXTDescription {
    /// Reads the BEXT chunk from a WAV file. Returns `nil` if the file has no BEXT data.
    public init?(url: URL) {
        guard let info = BEXTDescriptionC(path: url.path) else {
            return nil
        }

        self = BEXTDescription(info: info)
    }

    /// Creates a `BEXTDescription` from the C bridge object, populating version-appropriate fields.
    public init(info: BEXTDescriptionC) {
        self.init()

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

    /// Converts to the C bridge representation for writing via libsndfile.
    /// The BWF version is automatically upgraded when v1 or v2 fields are present.
    public var bextDescriptionC: BEXTDescriptionC {
        let info = BEXTDescriptionC()

        func updateVersion(_ requiredVersion: Int16) {
            if info.version < requiredVersion {
                info.version = requiredVersion
            }
        }

        // Preserve the original version, only upgrade based on content
        info.version = version

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
            info.timeReferenceLow = UInt32(clamping: timeReferenceLow)
        }

        if let timeReferenceHigh {
            info.timeReferenceHigh = UInt32(clamping: timeReferenceHigh)
        }

        return info
    }

    /// Writes this BEXTDescription to file. The data will be validated before writing.
    public static func write(bextDescription: BEXTDescription, to url: URL) throws {
        let cObject = bextDescription.bextDescriptionC

        guard BEXTDescriptionC.write(cObject, path: url.path) else {
            throw NSError(description: "Failed to write BEXT chunk to \(url.path)")
        }
    }
}
