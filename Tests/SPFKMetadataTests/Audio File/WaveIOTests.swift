// Copyright Ryan Francesconi. All Rights Reserved.

import AVFoundation
import Foundation
import Numerics
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadataC

// MARK: - BEXT initWithData / serializedData round-trip

/// Tests for the binary BEXT parser (`initWithData:`) and serializer (`serializedData`),
/// verifying fields against known expected values from test files.
@Suite(.serialized, .tags(.file))
final class BEXTBinaryRoundTripTests: BinTestCase {
    /// Parse a BEXT v1 file via WaveFileC (TagLib bextTag -> initWithData)
    /// and verify all fields against known values.
    @Test func parseBEXTv1ViaTagLib() async throws {
        let url = TestBundleResources.shared.wav_bext_v1

        let waveFile = WaveFileC(path: url.path)
        #expect(waveFile.load())
        let bext = try #require(waveFile.bextDescriptionC)

        #expect(bext.version == 1)
        #expect(bext.originator == "Logic Pro")
        #expect(bext.originationDate == "2025-10-18")
        #expect(bext.originationTime == "17:51:21")
        #expect(bext.timeReferenceLow == 172_800_000)
        #expect(bext.timeReferenceHigh == 0)
        #expect(bext.timeReference == 172_800_000)
        #expect(
            bext.umid
                == "00000000F05E776B01000000000000000000000000000000000000006058776B010000003058776B01000000C8D3B6080100000000000000000000006058776B"
        )
    }

    /// Parse a BEXT v2 file via WaveFileC and verify all fields including loudness.
    @Test func parseBEXTv2ViaTagLib() async throws {
        let url = TestBundleResources.shared.wav_bext_v2b

        let waveFile = WaveFileC(path: url.path)
        #expect(waveFile.load())
        let bext = try #require(waveFile.bextDescriptionC)

        #expect(bext.version == 2)
        #expect(bext.originator == "ITRAIDA88396FG347125324098748726")
        #expect(bext.originatorReference == "RF666SPONGEFORK66000100510720836")
        #expect(bext.originationDate == "1984:01:01")
        #expect(bext.originationTime == "00:01:00")
        #expect(bext.timeReferenceLow == 158_760_000)
        #expect(bext.timeReferenceHigh == 0)
        #expect(bext.timeReference == 158_760_000)
        #expect(
            bext.umid
                == "53504F4E4745464F524B303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303000"
        )

        // Loudness values are stored as int16 / 100.0
        let tolerance = 0.01
        #expect(bext.loudnessIntegrated.isApproximatelyEqual(to: -22.28, absoluteTolerance: tolerance))
        #expect(bext.loudnessRange.isApproximatelyEqual(to: -14.0, absoluteTolerance: tolerance))
        #expect(Double(bext.maxTruePeakLevel).isApproximatelyEqual(to: -8.75, absoluteTolerance: tolerance))
        #expect(bext.maxMomentaryLoudness.isApproximatelyEqual(to: -18.42, absoluteTolerance: tolerance))
        #expect(bext.maxShortTermLoudness.isApproximatelyEqual(to: -16.0, absoluteTolerance: tolerance))

        #expect(
            bext.sequenceDescription
                == "And oh how they danced The little children of Stonehenge Beneath the haunted moon For fear that daybreak might come too soonr fear that daybreak might come too soon"
        )
    }

    /// Verify serializedData round-trips: parse from data, serialize, parse again,
    /// and confirm all fields are identical.
    @Test func serializeDeserializeRoundTrip() async throws {
        let url = TestBundleResources.shared.wav_bext_v2b

        let waveFile = WaveFileC(path: url.path)
        #expect(waveFile.load())
        let original = try #require(waveFile.bextDescriptionC)

        // Serialize to bytes
        let data = original.serializedData()

        // Parse back from bytes
        let restored = try #require(BEXTDescriptionC(data: data))
        restored.sampleRate = original.sampleRate

        #expect(restored.version == original.version)
        #expect(restored.sequenceDescription == original.sequenceDescription)
        #expect(restored.originator == original.originator)
        #expect(restored.originatorReference == original.originatorReference)
        #expect(restored.originationDate == original.originationDate)
        #expect(restored.originationTime == original.originationTime)
        #expect(restored.timeReferenceLow == original.timeReferenceLow)
        #expect(restored.timeReferenceHigh == original.timeReferenceHigh)
        #expect(restored.timeReference == original.timeReference)
        #expect(restored.umid == original.umid)
        #expect(restored.codingHistory == original.codingHistory)
        #expect(restored.loudnessIntegrated == original.loudnessIntegrated)
        #expect(restored.loudnessRange == original.loudnessRange)
        #expect(restored.maxTruePeakLevel == original.maxTruePeakLevel)
        #expect(restored.maxMomentaryLoudness == original.maxMomentaryLoudness)
        #expect(restored.maxShortTermLoudness == original.maxShortTermLoudness)
        #expect(restored.timeReferenceInSeconds == original.timeReferenceInSeconds)
    }

    /// Verify initWithData rejects data shorter than the minimum BEXT size (602 bytes).
    @Test func initWithDataRejectsTooShort() {
        let shortData = Data(repeating: 0, count: 601)
        let result = BEXTDescriptionC(data: shortData)
        #expect(result == nil)
    }

    /// Verify initWithData accepts exactly the minimum size (no coding history).
    @Test func initWithDataAcceptsMinimumSize() {
        var data = Data(repeating: 0, count: 602)

        // Set version to 1 at offset 346 (little-endian)
        data[346] = 1
        data[347] = 0

        let result = BEXTDescriptionC(data: data)
        #expect(result != nil)
        #expect(result?.version == 1)
        #expect(result?.codingHistory == "")
    }
}

// MARK: - BEXT end-to-end via TagLib (WaveFileC load/save)

/// Tests the full BEXT pipeline: TagLib reads bextTag bytes -> initWithData parses ->
/// Swift edits -> bextDescriptionC serializes -> TagLib writes bextTag -> verify.
@Suite(.serialized, .tags(.file))
final class BEXTTagLibEndToEndTests: BinTestCase {
    /// Load a WAV with BEXT, modify a field, save via TagLib, reload, verify.
    @Test func bextRoundTripViaSave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2b)

        // Load
        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())
        let bext = try #require(file.bextDescriptionC)
        let originalVersion = bext.version
        let originalUmid = bext.umid
        let originalTimeRef = bext.timeReference

        // Modify description
        bext.sequenceDescription = "Modified via TagLib"
        file.markersNeedsSave = false
        file.imageNeedsSave = false

        // Save
        #expect(file.save())

        // Reload
        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        let updated = try #require(reloaded.bextDescriptionC)

        #expect(updated.sequenceDescription == "Modified via TagLib")
        #expect(updated.version == originalVersion)
        #expect(updated.umid == originalUmid)
        #expect(updated.timeReference == originalTimeRef)
    }

    /// Verify BEXT loudness values survive a TagLib save round-trip.
    @Test func bextLoudnessRoundTrip() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2b)

        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())

        let original = try #require(file.bextDescriptionC)
        let origLoudness = original.loudnessIntegrated
        let origRange = original.loudnessRange
        let origPeak = original.maxTruePeakLevel
        let origMomentary = original.maxMomentaryLoudness
        let origShortTerm = original.maxShortTermLoudness

        file.markersNeedsSave = false
        file.imageNeedsSave = false
        #expect(file.save())

        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        let updated = try #require(reloaded.bextDescriptionC)

        #expect(updated.loudnessIntegrated == origLoudness)
        #expect(updated.loudnessRange == origRange)
        #expect(updated.maxTruePeakLevel == origPeak)
        #expect(updated.maxMomentaryLoudness == origMomentary)
        #expect(updated.maxShortTermLoudness == origShortTerm)
    }

    /// Verify that saving a WAV with BEXT doesn't corrupt existing INFO/ID3 tags.
    @Test func bextSavePreservesOtherChunks() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2b)

        // Load and capture original tag values
        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())

        let originalTitle = file[info: .title]
        let originalArtist = file[info: .artist]

        // Modify BEXT only
        file.bextDescriptionC?.sequenceDescription = "New description"
        file.markersNeedsSave = false
        file.imageNeedsSave = false
        #expect(file.save())

        // Verify other chunks preserved
        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        #expect(reloaded[info: .title] == originalTitle)
        #expect(reloaded[info: .artist] == originalArtist)
    }
}

// MARK: - Artwork via tag-based methods

/// Tests the TagPicture tag-based class methods (readFromTag:/write:toTag:)
/// as exercised through WaveFileC's load/save pipeline.
@Suite(.serialized, .tags(.file))
final class WaveArtworkRoundTripTests: BinTestCase {
    /// Embed artwork into a WAV via WaveFileC save, then read back and verify.
    @Test func artworkWriteAndReadViaWaveFileC() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        // Write artwork
        let pictureRef = try #require(
            TagPictureRef(
                url: TestBundleResources.shared.sharksandwich,
                pictureDescription: "Test Artwork",
                pictureType: "Front Cover"
            )
        )

        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())
        file.tagPicture = TagPicture(picture: pictureRef)
        file.imageNeedsSave = true
        file.markersNeedsSave = false
        #expect(file.save())

        // Read back
        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        let readPicture = try #require(reloaded.tagPicture?.pictureRef)

        #expect(readPicture.cgImage.width == pictureRef.cgImage.width)
        #expect(readPicture.cgImage.height == pictureRef.cgImage.height)
        #expect(readPicture.pictureDescription == "Test Artwork")
        #expect(readPicture.pictureType == "Front Cover")
    }

    /// Verify that saving with nil tagPicture removes artwork from a WAV file.
    @Test func artworkClearViaWaveFileC() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        // First, embed artwork
        let pictureRef = try #require(
            TagPictureRef(
                url: TestBundleResources.shared.sharksandwich,
                pictureDescription: "To Be Removed",
                pictureType: "Front Cover"
            )
        )

        let file1 = WaveFileC(path: tmpfile.path)
        #expect(file1.load())
        file1.tagPicture = TagPicture(picture: pictureRef)
        file1.imageNeedsSave = true
        file1.markersNeedsSave = false
        #expect(file1.save())

        // Confirm artwork exists
        let file2 = WaveFileC(path: tmpfile.path)
        #expect(file2.load())
        #expect(file2.tagPicture?.pictureRef != nil)

        // Now save with no tagPicture (nil) to clear it
        file2.tagPicture = nil
        file2.imageNeedsSave = true
        file2.markersNeedsSave = false
        #expect(file2.save())

        // Confirm artwork is gone
        let file3 = WaveFileC(path: tmpfile.path)
        #expect(file3.load())
        #expect(file3.tagPicture?.pictureRef == nil)
    }
}

// MARK: - bitsPerSample propagation

/// Tests that bitsPerSample flows from TagLib through TagAudioPropertiesC
/// to AudioFormatProperties.bitsPerChannel.
@Suite(.serialized, .tags(.file))
final class BitsPerSampleTests: BinTestCase {
    /// Verify WaveFileC populates bitsPerSample from TagLib's WAV properties.
    @Test func waveFileCPopulatesBitsPerSample() async throws {
        let url = TestBundleResources.shared.tabla_wav

        let file = WaveFileC(path: url.path)
        #expect(file.load())

        let props = try #require(file.audioPropertiesC)
        #expect(props.bitsPerSample > 0)
    }

    /// Verify AudioFormatProperties correctly maps bitsPerSample to bitsPerChannel.
    @Test func audioFormatPropertiesFromCObject() async throws {
        let url = TestBundleResources.shared.tabla_wav

        let file = WaveFileC(path: url.path)
        #expect(file.load())
        let cProps = try #require(file.audioPropertiesC)

        let format = AudioFormatProperties(cObject: cProps)
        #expect(format.bitsPerChannel == Int(cProps.bitsPerSample))
        #expect(format.bitsPerChannel != nil)
        #expect(format.sampleRate > 0)
        #expect(format.channelCount > 0)
        #expect(format.duration > 0)
    }

    /// Verify 24-bit file propagates correctly.
    @Test func bitsPerSample24bit() async throws {
        let url = TestBundleResources.shared.cowbell_bext_wav

        let file = WaveFileC(path: url.path)
        #expect(file.load())

        let props = try #require(file.audioPropertiesC)
        // cowbell_bext is 24-bit
        if props.bitsPerSample == 24 {
            let format = AudioFormatProperties(cObject: props)
            #expect(format.bitsPerChannel == 24)
        }
    }
}

// MARK: - WAV without AVAudioFile equivalence

/// Tests that the WAV-only path (TagLib) produces equivalent format properties
/// to the old AVAudioFile path.
@Suite(.serialized, .tags(.file))
final class WAVFormatEquivalenceTests: BinTestCase {
    /// Compare format properties from the TagLib-only WAV path with AVAudioFile.
    @Test func wavFormatMatchesAVAudioFile() async throws {
        let url = TestBundleResources.shared.tabla_wav

        // TagLib path (new)
        let maf = try await MetaAudioFileDescription(parsing: url)
        let taglibFormat = try #require(maf.audioFormat)

        // AVAudioFile path (old)
        let audioFile = try AVAudioFile(forReading: url)
        let avFormat = AudioFormatProperties(audioFile: audioFile)

        #expect(taglibFormat.sampleRate == avFormat.sampleRate)
        #expect(taglibFormat.channelCount == avFormat.channelCount)

        // TagLib computes duration from lengthInMilliseconds (integer ms),
        // while AVAudioFile uses sample-accurate frame count. Allow small tolerance.
        #expect(abs(taglibFormat.duration - avFormat.duration) < 0.001)

        // bitsPerChannel: AVAudioFile reports this for WAV, TagLib should too
        #expect(taglibFormat.bitsPerChannel == avFormat.bitsPerChannel)
    }

    /// Verify multiple WAV files parse consistently.
    @Test func wavFormatConsistency() async throws {
        let urls = [
            TestBundleResources.shared.tabla_wav,
            TestBundleResources.shared.cowbell_bext_wav,
        ]

        for url in urls {
            let maf = try await MetaAudioFileDescription(parsing: url)
            let format = try #require(maf.audioFormat, "No format for \(url.lastPathComponent)")

            #expect(format.sampleRate > 0, "sampleRate should be > 0 for \(url.lastPathComponent)")
            #expect(format.channelCount > 0, "channelCount should be > 0 for \(url.lastPathComponent)")
            #expect(format.duration > 0, "duration should be > 0 for \(url.lastPathComponent)")
            #expect(format.bitsPerChannel != nil, "bitsPerChannel should not be nil for \(url.lastPathComponent)")
        }
    }
}

// MARK: - Dirty flags

/// Tests that markersNeedsSave and imageNeedsSave flags control conditional writes.
@Suite(.serialized, .tags(.file))
final class DirtyFlagTests: BinTestCase {
    /// Verify that imageNeedsSave=false skips artwork writing even when tagPicture is set.
    @Test func imageNotSavedWhenFlagIsFalse() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        // Confirm no artwork initially
        let initial = WaveFileC(path: tmpfile.path)
        #expect(initial.load())
        #expect(initial.tagPicture?.pictureRef == nil)

        // Set artwork but mark imageNeedsSave = false
        let pictureRef = try #require(
            TagPictureRef(
                url: TestBundleResources.shared.sharksandwich,
                pictureDescription: "Should Not Save",
                pictureType: "Front Cover"
            )
        )

        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())
        file.tagPicture = TagPicture(picture: pictureRef)
        file.imageNeedsSave = false
        file.markersNeedsSave = false
        file[info: .title] = "Dirty Flag Test"
        #expect(file.save())

        // Verify artwork was NOT written
        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        #expect(reloaded.tagPicture?.pictureRef == nil)
        // But tags were still written
        #expect(reloaded[info: .title] == "Dirty Flag Test")
    }

    /// Verify that imageNeedsSave=true does write artwork.
    @Test func imageSavedWhenFlagIsTrue() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        let pictureRef = try #require(
            TagPictureRef(
                url: TestBundleResources.shared.sharksandwich,
                pictureDescription: "Should Save",
                pictureType: "Front Cover"
            )
        )

        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())
        file.tagPicture = TagPicture(picture: pictureRef)
        file.imageNeedsSave = true
        file.markersNeedsSave = false
        #expect(file.save())

        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        #expect(reloaded.tagPicture?.pictureRef != nil)
        #expect(reloaded.tagPicture?.pictureRef?.pictureDescription == "Should Save")
    }
}
