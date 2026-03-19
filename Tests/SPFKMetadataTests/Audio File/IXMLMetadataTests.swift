// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file), .serialized)
final class IXMLMetadataTests: BinTestCase {
    // MARK: - Parse

    @Test func parseBasicElements() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML>
            <IXML_VERSION>1.52</IXML_VERSION>
            <PROJECT>My Project</PROJECT>
            <SCENE>Scene 1</SCENE>
            <TAKE>Take 3</TAKE>
            <TAPE>Reel A</TAPE>
            <NOTE>A production note</NOTE>
            <CIRCLED>TRUE</CIRCLED>
        </BWFXML>
        """

        let metadata = try IXMLMetadata(xml: xml)

        #expect(metadata.version == "1.52")
        #expect(metadata.project == "My Project")
        #expect(metadata.scene == "Scene 1")
        #expect(metadata.take == "Take 3")
        #expect(metadata.tape == "Reel A")
        #expect(metadata.note == "A production note")
        #expect(metadata.circled == "TRUE")
    }

    @Test func parseSpeedContainer() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML>
            <IXML_VERSION>1.52</IXML_VERSION>
            <SPEED>
                <MASTER_SPEED>23.976</MASTER_SPEED>
                <CURRENT_SPEED>23.976</CURRENT_SPEED>
                <TIMECODE_RATE>2997ND</TIMECODE_RATE>
                <TIMECODE_FLAG>NDF</TIMECODE_FLAG>
                <FILE_SAMPLE_RATE>48000</FILE_SAMPLE_RATE>
                <AUDIO_BIT_DEPTH>24</AUDIO_BIT_DEPTH>
                <DIGITIZER_SAMPLE_RATE>48000</DIGITIZER_SAMPLE_RATE>
                <TIMESTAMP_SAMPLES_SINCE_MIDNIGHT_HI>0</TIMESTAMP_SAMPLES_SINCE_MIDNIGHT_HI>
                <TIMESTAMP_SAMPLES_SINCE_MIDNIGHT_LO>172800000</TIMESTAMP_SAMPLES_SINCE_MIDNIGHT_LO>
                <TIMESTAMP_SAMPLE_RATE>48000</TIMESTAMP_SAMPLE_RATE>
            </SPEED>
        </BWFXML>
        """

        let metadata = try IXMLMetadata(xml: xml)

        #expect(metadata.masterSpeed == "23.976")
        #expect(metadata.currentSpeed == "23.976")
        #expect(metadata.timecodeRate == "2997ND")
        #expect(metadata.timecodeFlag == "NDF")
        #expect(metadata.fileSampleRate == "48000")
        #expect(metadata.audioBitDepth == "24")
        #expect(metadata.digitizerSampleRate == "48000")
        #expect(metadata.timestampSamplesSinceMidnightHi == "0")
        #expect(metadata.timestampSamplesSinceMidnightLo == "172800000")
        #expect(metadata.timestampSampleRate == "48000")
    }

    @Test func parseTrackList() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML>
            <IXML_VERSION>1.52</IXML_VERSION>
            <TRACK_LIST>
                <TRACK_COUNT>2</TRACK_COUNT>
                <TRACK>
                    <CHANNEL_INDEX>1</CHANNEL_INDEX>
                    <INTERLEAVE_INDEX>1</INTERLEAVE_INDEX>
                    <NAME>Boom</NAME>
                    <FUNCTION>INPUT</FUNCTION>
                </TRACK>
                <TRACK>
                    <CHANNEL_INDEX>2</CHANNEL_INDEX>
                    <INTERLEAVE_INDEX>2</INTERLEAVE_INDEX>
                    <NAME>Lav 1</NAME>
                    <FUNCTION>INPUT</FUNCTION>
                </TRACK>
            </TRACK_LIST>
        </BWFXML>
        """

        let metadata = try IXMLMetadata(xml: xml)

        let tracks = try #require(metadata.tracks)
        #expect(tracks.count == 2)
        #expect(tracks[0].channelIndex == "1")
        #expect(tracks[0].name == "Boom")
        #expect(tracks[0].function == "INPUT")
        #expect(tracks[1].channelIndex == "2")
        #expect(tracks[1].name == "Lav 1")
    }

    @Test func parseLoudnessContainer() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML>
            <LOUDNESS>
                <LOUDNESS_VALUE>-24.10</LOUDNESS_VALUE>
                <LOUDNESS_RANGE>7.50</LOUDNESS_RANGE>
                <MAX_TRUE_PEAK_LEVEL>-0.10</MAX_TRUE_PEAK_LEVEL>
                <MAX_MOMENTARY>-19.50</MAX_MOMENTARY>
                <MAX_SHORT_TERM>-23.00</MAX_SHORT_TERM>
            </LOUDNESS>
        </BWFXML>
        """

        let metadata = try IXMLMetadata(xml: xml)
        let loudness = try #require(metadata.loudnessDescription)

        #expect(loudness.loudnessIntegrated == -24.10)
        #expect(loudness.loudnessRange == 7.50)
        #expect(loudness.maxTruePeakLevel == -0.10)
        #expect(loudness.maxMomentaryLoudness == -19.50)
        #expect(loudness.maxShortTermLoudness == -23.00)
    }

    @Test func parseBextContainer() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML>
            <BEXT>
                <BWF_VERSION>2</BWF_VERSION>
                <BWF_DESCRIPTION>A recording session</BWF_DESCRIPTION>
                <BWF_ORIGINATOR>Sound Devices</BWF_ORIGINATOR>
                <BWF_ORIGINATOR_REFERENCE>SD-001</BWF_ORIGINATOR_REFERENCE>
                <BWF_ORIGINATION_DATE>2024-03-15</BWF_ORIGINATION_DATE>
                <BWF_ORIGINATION_TIME>14:30:00</BWF_ORIGINATION_TIME>
                <BWF_TIME_REFERENCE_LOW>172800000</BWF_TIME_REFERENCE_LOW>
                <BWF_TIME_REFERENCE_HIGH>0</BWF_TIME_REFERENCE_HIGH>
                <BWF_CODING_HISTORY>A=PCM,F=48000,W=24,M=stereo,T=original</BWF_CODING_HISTORY>
            </BEXT>
        </BWFXML>
        """

        let metadata = try IXMLMetadata(xml: xml)

        #expect(metadata.bextVersion == "2")
        #expect(metadata.bextDescriptionText == "A recording session")
        #expect(metadata.bextOriginator == "Sound Devices")
        #expect(metadata.bextOriginatorReference == "SD-001")
        #expect(metadata.bextOriginationDate == "2024-03-15")
        #expect(metadata.bextOriginationTime == "14:30:00")
        #expect(metadata.bextTimeReferenceLow == "172800000")
        #expect(metadata.bextTimeReferenceHigh == "0")
        #expect(metadata.bextCodingHistory == "A=PCM,F=48000,W=24,M=stereo,T=original")
    }

    @Test func parseHistoryContainer() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML>
            <HISTORY>
                <ORIGINAL_FILENAME>recording_001.wav</ORIGINAL_FILENAME>
                <PARENT_FILENAME>session_master.wav</PARENT_FILENAME>
                <PARENT_UID>ABC123</PARENT_UID>
            </HISTORY>
        </BWFXML>
        """

        let metadata = try IXMLMetadata(xml: xml)

        #expect(metadata.originalFilename == "recording_001.wav")
        #expect(metadata.parentFilename == "session_master.wav")
        #expect(metadata.parentUID == "ABC123")
    }

    @Test func parseFromWaveFile() async throws {
        let url = TestBundleResources.shared.ixml_chunk
        let file = WaveFileC(path: url.path)
        #expect(file.load())

        let ixmlString = try #require(file.iXML)
        let metadata = try IXMLMetadata(xml: ixmlString)

        // The ixml_chunk test file should have at least a version
        Log.debug("Parsed iXML version:", metadata.version ?? "nil")
        Log.debug("Parsed iXML project:", metadata.project ?? "nil")
    }

    // MARK: - Create

    @Test func createMinimalDocument() {
        var metadata = IXMLMetadata()
        metadata.version = "1.52"
        metadata.project = "Test Project"

        let xml = metadata.xml
        #expect(xml.contains("<IXML_VERSION>1.52</IXML_VERSION>"))
        #expect(xml.contains("<PROJECT>Test Project</PROJECT>"))
        #expect(xml.contains("<BWFXML>"))
    }

    @Test func createWithSpeedContainer() {
        var metadata = IXMLMetadata()
        metadata.version = "1.52"
        metadata.fileSampleRate = "48000"
        metadata.audioBitDepth = "24"
        metadata.timecodeRate = "25"

        let xml = metadata.xml
        #expect(xml.contains("<SPEED>"))
        #expect(xml.contains("<FILE_SAMPLE_RATE>48000</FILE_SAMPLE_RATE>"))
        #expect(xml.contains("<AUDIO_BIT_DEPTH>24</AUDIO_BIT_DEPTH>"))
        #expect(xml.contains("<TIMECODE_RATE>25</TIMECODE_RATE>"))
    }

    @Test func createWithTrackList() {
        var metadata = IXMLMetadata()
        metadata.version = "1.52"
        metadata.tracks = [
            .init(channelIndex: "1", interleaveIndex: "1", name: "Left", function: "INPUT"),
            .init(channelIndex: "2", interleaveIndex: "2", name: "Right", function: "INPUT"),
        ]

        let xml = metadata.xml
        #expect(xml.contains("<TRACK_LIST>"))
        #expect(xml.contains("<TRACK_COUNT>2</TRACK_COUNT>"))
        #expect(xml.contains("<NAME>Left</NAME>"))
        #expect(xml.contains("<NAME>Right</NAME>"))
    }

    @Test func createWithLoudness() {
        var metadata = IXMLMetadata()
        metadata.loudnessDescription = LoudnessDescription(
            loudnessIntegrated: -24.1,
            loudnessRange: 7.5,
            maxTruePeakLevel: -0.1
        )

        let xml = metadata.xml
        #expect(xml.contains("<LOUDNESS>"))
        #expect(xml.contains("<LOUDNESS_VALUE>-24.10</LOUDNESS_VALUE>"))
        #expect(xml.contains("<LOUDNESS_RANGE>7.50</LOUDNESS_RANGE>"))
        #expect(xml.contains("<MAX_TRUE_PEAK_LEVEL>-0.10</MAX_TRUE_PEAK_LEVEL>"))
    }

    @Test func nilPropertiesAreOmitted() {
        let metadata = IXMLMetadata()
        let xml = metadata.xml

        // An empty metadata should produce a minimal document (self-closing <BWFXML />)
        #expect(xml.contains("<BWFXML"))
        #expect(!xml.contains("<SPEED>"))
        #expect(!xml.contains("<TRACK_LIST>"))
        #expect(!xml.contains("<LOUDNESS>"))
        #expect(!xml.contains("<BEXT>"))
        #expect(!xml.contains("<HISTORY>"))
    }

    // MARK: - Round Trip

    @Test func roundTripPreservesValues() throws {
        var original = IXMLMetadata()
        original.version = "1.52"
        original.project = "Round Trip Test"
        original.scene = "SC01"
        original.take = "T03"
        original.note = "Test note"
        original.fileSampleRate = "96000"
        original.audioBitDepth = "32"
        original.tracks = [
            .init(channelIndex: "1", name: "Mono"),
        ]

        let xml = original.xml
        let parsed = try IXMLMetadata(xml: xml)

        #expect(parsed.version == "1.52")
        #expect(parsed.project == "Round Trip Test")
        #expect(parsed.scene == "SC01")
        #expect(parsed.take == "T03")
        #expect(parsed.note == "Test note")
        #expect(parsed.fileSampleRate == "96000")
        #expect(parsed.audioBitDepth == "32")
        #expect(parsed.tracks?.count == 1)
        #expect(parsed.tracks?.first?.name == "Mono")
    }

    @Test func roundTripLoudness() throws {
        var original = IXMLMetadata()
        original.loudnessDescription = LoudnessDescription(
            loudnessIntegrated: -23.5,
            loudnessRange: 12.0,
            maxTruePeakLevel: -1.5,
            maxMomentaryLoudness: -18.0,
            maxShortTermLoudness: -20.0
        )

        let xml = original.xml
        let parsed = try IXMLMetadata(xml: xml)
        let loudness = try #require(parsed.loudnessDescription)

        #expect(loudness.loudnessIntegrated == -23.5)
        #expect(loudness.loudnessRange == 12.0)
        #expect(loudness.maxTruePeakLevel == -1.5)
        #expect(loudness.maxMomentaryLoudness == -18.0)
        #expect(loudness.maxShortTermLoudness == -20.0)
    }

    // MARK: - Create from MetaAudioFileDescription

    @Test func createFromDescription() throws {
        let url = URL(fileURLWithPath: "/tmp/test_recording.wav")

        var desc = MetaAudioFileDescription(
            url: url,
            fileType: .wav,
            audioFormat: AudioFormatProperties(
                channelCount: 2,
                sampleRate: 48000,
                bitsPerChannel: 24,
                duration: 10.0
            )
        )

        desc.set(tag: .album, value: "My Project")
        desc.set(tag: .comment, value: "Session notes here")

        var bext = BEXTDescription()
        bext.version = 2
        bext.sequenceDescription = "Recording session"
        bext.originator = "ShadowTag"
        bext.originationDate = "2024-03-15"
        bext.originationTime = "14:30:00"
        bext.loudnessDescription = LoudnessDescription(
            loudnessIntegrated: -24.1,
            loudnessRange: 7.5,
            maxTruePeakLevel: -0.1
        )
        desc.bextDescription = bext

        let metadata = IXMLMetadata(from: desc)

        #expect(metadata.version == "1.52")
        #expect(metadata.project == "My Project")
        #expect(metadata.note == "Session notes here")
        #expect(metadata.fileSampleRate == "48000")
        #expect(metadata.audioBitDepth == "24")
        #expect(metadata.originalFilename == "test_recording.wav")

        // BEXT container
        #expect(metadata.bextVersion == "2")
        #expect(metadata.bextDescriptionText == "Recording session")
        #expect(metadata.bextOriginator == "ShadowTag")

        // Loudness
        let loudness = try #require(metadata.loudnessDescription)
        #expect(loudness.loudnessIntegrated == -24.1)

        // Track list
        let tracks = try #require(metadata.tracks)
        #expect(tracks.count == 2)
        #expect(tracks[0].channelIndex == "1")
        #expect(tracks[1].channelIndex == "2")

        // Verify it generates valid XML
        let xml = metadata.xml
        let reparsed = try IXMLMetadata(xml: xml)
        #expect(reparsed.project == "My Project")
    }

    // MARK: - Error Handling

    @Test func invalidXMLThrows() {
        #expect(throws: Error.self) {
            _ = try IXMLMetadata(xml: "not xml at all")
        }
    }

    @Test func emptyXMLProducesEmptyMetadata() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML />
        """

        let metadata = try IXMLMetadata(xml: xml)
        #expect(metadata.version == nil)
        #expect(metadata.project == nil)
        #expect(metadata.tracks == nil)
    }
}
