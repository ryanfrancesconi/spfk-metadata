import Foundation
@testable import SPFKMetadata
import Testing

// MARK: - BEXTDescription Codable round-trip and dictionary tests

struct BEXTCodableTests {
    @Test func codableRoundTripV0() throws {
        var original = BEXTDescription()
        original.version = 0
        original.sequenceDescription = "Test Description"
        original.originator = "Test Originator"
        original.originatorReference = "REF123"
        original.originationDate = "2025-01-15"
        original.originationTime = "14:30:00"
        original.codingHistory = "A=PCM,F=44100,W=16,M=stereo"
        original.timeReferenceLow = 44100
        original.timeReferenceHigh = 0

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BEXTDescription.self, from: data)

        #expect(decoded.version == 0)
        #expect(decoded.sequenceDescription == "Test Description")
        #expect(decoded.originator == "Test Originator")
        #expect(decoded.originatorReference == "REF123")
        #expect(decoded.originationDate == "2025-01-15")
        #expect(decoded.originationTime == "14:30:00")
        #expect(decoded.codingHistory == "A=PCM,F=44100,W=16,M=stereo")
        #expect(decoded.timeReferenceLow == 44100)
        #expect(decoded.timeReferenceHigh == 0)
        // version 0: no UMID
        #expect(decoded.umid == nil)
    }

    @Test func codableRoundTripV1() throws {
        var original = BEXTDescription()
        original.version = 1
        original.umid = "TESTUMID123"
        original.originator = "Logic Pro"

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BEXTDescription.self, from: data)

        #expect(decoded.version == 1)
        #expect(decoded.umid == "TESTUMID123")
        #expect(decoded.originator == "Logic Pro")
    }

    @Test func codableRoundTripV2() throws {
        var original = BEXTDescription()
        original.version = 2
        original.umid = "UMID"
        original.loudnessDescription.loudnessIntegrated = -23.0
        original.loudnessDescription.loudnessRange = -14.0
        original.loudnessDescription.maxTruePeakLevel = -1.0
        original.loudnessDescription.maxMomentaryLoudness = -20.0
        original.loudnessDescription.maxShortTermLoudness = -18.0

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BEXTDescription.self, from: data)

        #expect(decoded.version == 2)
        #expect(decoded.loudnessDescription.loudnessIntegrated == -23.0)
        #expect(decoded.loudnessDescription.loudnessRange == -14.0)
        #expect(decoded.loudnessDescription.maxTruePeakLevel == -1.0)
        #expect(decoded.loudnessDescription.maxMomentaryLoudness == -20.0)
        #expect(decoded.loudnessDescription.maxShortTermLoudness == -18.0)
    }

    @Test func codableV0DoesNotDecodeLoudness() throws {
        var original = BEXTDescription()
        original.version = 0

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BEXTDescription.self, from: data)

        #expect(decoded.loudnessDescription.loudnessIntegrated == nil)
    }

    @Test func codableEmpty() throws {
        let original = BEXTDescription()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BEXTDescription.self, from: data)

        #expect(decoded.version == 0)
        #expect(decoded.sequenceDescription == nil)
        #expect(decoded.originator == nil)
    }
}

// MARK: - BEXTDescription.validated()

struct BEXTValidatedTests {
    @Test func validatedClearsAllZeroUmid() {
        var desc = BEXTDescription()
        desc.umid = "0000000000"
        let validated = desc.validated()
        #expect(validated.umid == "")
    }

    @Test func validatedClearsAllZeroDate() {
        var desc = BEXTDescription()
        desc.originationDate = "0000000000"
        let validated = desc.validated()
        #expect(validated.originationDate == "")
    }

    @Test func validatedClearsAllZeroTime() {
        var desc = BEXTDescription()
        desc.originationTime = "00000000"
        let validated = desc.validated()
        #expect(validated.originationTime == "")
    }

    @Test func validatedClearsZeroTimeRef() {
        var desc = BEXTDescription()
        desc.timeReferenceLow = 0
        desc.timeReferenceHigh = 0
        let validated = desc.validated()
        #expect(validated.timeReferenceLow == nil)
        #expect(validated.timeReferenceHigh == nil)
    }

    @Test func validatedPreservesNonZero() {
        var desc = BEXTDescription()
        desc.umid = "SPONGEFORK"
        desc.originationDate = "2025-01-01"
        desc.originationTime = "12:00:00"
        desc.timeReferenceLow = 44100
        desc.timeReferenceHigh = 1

        let validated = desc.validated()
        #expect(validated.umid == "SPONGEFORK")
        #expect(validated.originationDate == "2025-01-01")
        #expect(validated.originationTime == "12:00:00")
        #expect(validated.timeReferenceLow == 44100)
        #expect(validated.timeReferenceHigh == 1)
    }
}

// MARK: - BEXTDescription timeReference

struct BEXTTimeReferenceTests {
    @Test func timeReferenceGetSet() {
        var desc = BEXTDescription()
        desc.timeReference = 88200

        #expect(desc.timeReferenceLow == 88200)
        #expect(desc.timeReferenceHigh == 0)
        #expect(desc.timeReference == 88200)
    }

    @Test func timeReferenceNil() {
        var desc = BEXTDescription()
        #expect(desc.timeReference == nil)

        desc.timeReference = 100
        #expect(desc.timeReference == 100)

        desc.timeReference = nil
        #expect(desc.timeReferenceLow == nil)
        #expect(desc.timeReferenceHigh == nil)
    }

    @Test func timeReferencePartialNilLow() {
        var desc = BEXTDescription()
        desc.timeReferenceHigh = 1
        // low is nil, so timeReference should be nil
        #expect(desc.timeReference == nil)
    }

    @Test func timeReferencePartialNilHigh() {
        var desc = BEXTDescription()
        desc.timeReferenceLow = 1000
        // high is nil, so timeReference should be nil
        #expect(desc.timeReference == nil)
    }

    @Test func timeReferenceInSeconds() {
        var desc = BEXTDescription()
        desc.timeReferenceLow = 88200
        desc.timeReferenceHigh = 0
        desc.sampleRate = 44100

        #expect(desc.timeReferenceInSeconds == 2.0)
    }

    @Test func timeReferenceInSecondsNilWithoutSampleRate() {
        var desc = BEXTDescription()
        desc.timeReferenceLow = 88200
        desc.timeReferenceHigh = 0

        #expect(desc.timeReferenceInSeconds == nil)
    }

    @Test func timeReferenceInSecondsNilWithZeroSampleRate() {
        var desc = BEXTDescription()
        desc.timeReferenceLow = 88200
        desc.timeReferenceHigh = 0
        desc.sampleRate = 0

        #expect(desc.timeReferenceInSeconds == nil)
    }

    @Test func timeReferenceString() {
        var desc = BEXTDescription()
        desc.timeReferenceLow = 172_800_000
        desc.timeReferenceHigh = 0
        desc.sampleRate = 48000

        let str = desc.timeReferenceString
        #expect(str != nil)
        #expect(str!.contains("1:00:00"))
    }

    @Test func timeReferenceStringNil() {
        let desc = BEXTDescription()
        #expect(desc.timeReferenceString == nil)
    }
}

// MARK: - BEXTDescription.Key

struct BEXTKeyTests {
    @Test func displayNames() {
        #expect(BEXTDescription.Key.originator.displayName == "Originator")
        #expect(BEXTDescription.Key.version.displayName == "Version")
        #expect(BEXTDescription.Key.description.displayName == "Description")
        #expect(BEXTDescription.Key.umid.displayName == "UMID")
    }

    @Test func initFromDisplayName() {
        for key in BEXTDescription.Key.allCases {
            let recovered = BEXTDescription.Key(displayName: key.displayName)
            #expect(recovered == key, "Failed round-trip for \(key)")
        }
    }

    @Test func initFromDisplayNameNil() {
        #expect(BEXTDescription.Key(displayName: "Nonexistent") == nil)
    }

    @Test func isEditable() {
        #expect(BEXTDescription.Key.originator.isEditable)
        #expect(BEXTDescription.Key.description.isEditable)
        #expect(BEXTDescription.Key.umid.isEditable)
        #expect(!BEXTDescription.Key.version.isEditable)
        #expect(!BEXTDescription.Key.codingHistory.isEditable)
    }

    @Test func descriptions() {
        // version has a description
        #expect(BEXTDescription.Key.version.description == "Version of the BWF")
        // originator has a description
        #expect(!BEXTDescription.Key.originator.description.isEmpty)
    }
}

// MARK: - BEXTDescription dictionary subscript

struct BEXTDictionaryTests {
    @Test func subscriptGet() {
        var desc = BEXTDescription()
        desc.originator = "Test"
        #expect(desc[.originator] == "Test")
    }

    @Test func subscriptSet() {
        var desc = BEXTDescription()
        desc[.originator] = "New Originator"
        #expect(desc.originator == "New Originator")
    }

    @Test func dictionaryGetter() {
        var desc = BEXTDescription()
        desc.originator = "Originator"
        desc.originationDate = "2025-01-01"
        desc.version = 2

        let dict = desc.dictionary
        #expect(dict[.originator] == "Originator")
        #expect(dict[.originationDate] == "2025-01-01")
        #expect(dict[.version] == "2")
    }

    @Test func dictionaryGetterNilValues() {
        let desc = BEXTDescription()
        let dict = desc.dictionary

        // nil properties should have nil values
        #expect(dict[.originator] == nil as String?)
        #expect(dict[.umid] == nil as String?)
    }

    @Test func dictionarySetter() {
        var desc = BEXTDescription()
        desc.dictionary = [
            .originator: "Ryan",
            .originatorReference: "REF123",
            .originationDate: "2025-06-15",
            .originationTime: "10:30:00",
            .umid: "UMID_VALUE",
            .description: "A description",
            .version: "2",
        ]

        #expect(desc.originator == "Ryan")
        #expect(desc.originatorReference == "REF123")
        #expect(desc.originationDate == "2025-06-15")
        #expect(desc.originationTime == "10:30:00")
        #expect(desc.umid == "UMID_VALUE")
        #expect(desc.sequenceDescription == "A description")
        #expect(desc.version == 2)
    }

    @Test func dictionaryInitializer() {
        let dict: BEXTKeyDictionary = [
            .originator: "Test",
            .version: "1",
        ]

        let desc = BEXTDescription(dictionary: dict)
        #expect(desc.originator == "Test")
        #expect(desc.version == 1)
    }
}
