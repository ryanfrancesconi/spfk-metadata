// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension BEXTDescription {
    /// Nil when the WAV has no BEXT chunk or can't be opened.
    public init?(url: URL) {
        let waveFile = WaveFileC(path: url.path)
        guard waveFile.load(), let info = waveFile.bextDescriptionC else {
            return nil
        }

        self = BEXTDescription(info: info)
    }

    /// UMID only from version 1, loudness only from version 2.
    init(info: BEXTDescriptionC) {
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

    /// The version is raised, never lowered, to fit a UMID (1) or loudness (2).
    var bextDescriptionC: BEXTDescriptionC {
        let info = BEXTDescriptionC()

        func updateVersion(_ requiredVersion: Int16) {
            if info.version < requiredVersion {
                info.version = requiredVersion
            }
        }

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

    /// WAV only; markers and artwork are left as they are.
    public static func write(bextDescription: BEXTDescription, to url: URL) throws {
        let waveFile = WaveFileC(path: url.path)
        guard waveFile.load() else {
            throw MetadataError.writeFailed(.bext, url)
        }

        waveFile.bextDescriptionC = bextDescription.bextDescriptionC
        waveFile.markersNeedsSave = false
        waveFile.imageNeedsSave = false

        guard waveFile.save() else {
            throw MetadataError.writeFailed(.bext, url)
        }
    }
}
