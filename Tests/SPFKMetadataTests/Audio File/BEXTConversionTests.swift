import Foundation
import SPFKMetadataC
import Testing

@testable import SPFKMetadata

// MARK: - BEXTDescription to BEXTDescriptionC conversion

struct BEXTConversionTests {
    @Test func bextDescriptionCBasicProperties() {
        var desc = BEXTDescription()
        desc.sequenceDescription = "Test Description"
        desc.originator = "Test Originator"
        desc.originatorReference = "REF123"
        desc.originationDate = "2025-01-15"
        desc.originationTime = "14:30:00"
        desc.codingHistory = "A=PCM,F=44100,W=16,M=stereo"
        desc.timeReferenceLow = 44100
        desc.timeReferenceHigh = 0

        let cObj = desc.bextDescriptionC

        #expect(cObj.sequenceDescription == "Test Description")
        #expect(cObj.originator == "Test Originator")
        #expect(cObj.originatorReference == "REF123")
        #expect(cObj.originationDate == "2025-01-15")
        #expect(cObj.originationTime == "14:30:00")
        #expect(cObj.codingHistory == "A=PCM,F=44100,W=16,M=stereo")
        #expect(cObj.timeReferenceLow == 44100)
        #expect(cObj.timeReferenceHigh == 0)
    }

    @Test func bextDescriptionCVersionAutoUpgradeForUmid() {
        var desc = BEXTDescription()
        desc.umid = "TESTUMID"

        let cObj = desc.bextDescriptionC
        // version should be auto-upgraded to at least 1 for UMID
        #expect(cObj.version >= 1)
        #expect(cObj.umid == "TESTUMID")
    }

    @Test func bextDescriptionCVersionAutoUpgradeForLoudness() {
        var desc = BEXTDescription()
        desc.loudnessDescription.loudnessIntegrated = -23.0

        let cObj = desc.bextDescriptionC
        // version should be auto-upgraded to 2 for loudness values
        #expect(cObj.version == 2)
    }

    @Test func bextDescriptionCVersionAutoUpgradeUmidAndLoudness() {
        var desc = BEXTDescription()
        desc.umid = "UMID"
        desc.loudnessDescription.loudnessIntegrated = -14.0
        desc.loudnessDescription.loudnessRange = -10.0

        let cObj = desc.bextDescriptionC
        // should be upgraded to 2 (highest needed)
        #expect(cObj.version == 2)
    }

    @Test func bextDescriptionCVersionZeroWhenNoV1V2Fields() {
        var desc = BEXTDescription()
        desc.originator = "Test"

        let cObj = desc.bextDescriptionC
        #expect(cObj.version == 0)
    }

    @Test func bextDescriptionCLoudnessValues() {
        var desc = BEXTDescription()
        desc.loudnessDescription.loudnessIntegrated = -22.5
        desc.loudnessDescription.loudnessRange = -14.0
        desc.loudnessDescription.maxTruePeakLevel = -1.5
        desc.loudnessDescription.maxMomentaryLoudness = -18.0
        desc.loudnessDescription.maxShortTermLoudness = -16.0

        let cObj = desc.bextDescriptionC
        #expect(cObj.loudnessIntegrated == -22.5)
        #expect(cObj.loudnessRange == -14.0)
        #expect(cObj.maxTruePeakLevel == -1.5)
        #expect(cObj.maxMomentaryLoudness == -18.0)
        #expect(cObj.maxShortTermLoudness == -16.0)
    }

    @Test func bextDescriptionCNilFieldsSkipped() {
        // default init — everything nil except version=0
        let desc = BEXTDescription()
        let cObj = desc.bextDescriptionC
        #expect(cObj.version == 0)
    }
}

// MARK: - BEXTDescription dictionary loudness setters

struct BEXTDictionaryLoudnessTests {
    @Test func setLoudnessViaDict() {
        var desc = BEXTDescription()
        desc.dictionary = [
            .loudnessIntegrated: "-14.0",
            .loudnessRange: "9.5",
            .maxTruePeakLevel: "-1.0",
            .maxMomentaryLoudness: "-10.0",
            .maxShortTermLoudness: "-12.0",
        ]

        #expect(desc.loudnessDescription.loudnessIntegrated == -14.0)
        #expect(desc.loudnessDescription.loudnessRange == 9.5)
        #expect(desc.loudnessDescription.maxTruePeakLevel == -1.0)
        #expect(desc.loudnessDescription.maxMomentaryLoudness == -10.0)
        #expect(desc.loudnessDescription.maxShortTermLoudness == -12.0)
    }

    @Test func setTimeReferenceViaDict() {
        var desc = BEXTDescription()
        desc.dictionary = [
            .timeReferenceSamples: "88200",
        ]

        #expect(desc.timeReference == 88200)
    }

    @Test func dictionaryGetLoudness() {
        var desc = BEXTDescription()
        desc.loudnessDescription.loudnessIntegrated = -23.0
        desc.loudnessDescription.loudnessRange = -14.0

        let dict = desc.dictionary
        #expect(dict[.loudnessIntegrated] != nil)
        #expect(dict[.loudnessRange] != nil)
    }
}
