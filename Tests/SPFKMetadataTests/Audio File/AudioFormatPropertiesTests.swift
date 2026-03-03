import AVFoundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

struct AudioFormatPropertiesAdditionalTests {
    // MARK: - info

    @Test(arguments: TestBundleResources.shared.formats)
    func printFormat(url: URL) async throws {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            Issue.record("\(url.lastPathComponent) failed to parse")
            return
        }

        let properties = AudioFormatProperties(audioFile: audioFile)
        Log.debug(url.lastPathComponent, properties.durationDescription, properties.formatDescription)
    }

    // MARK: - channelsDescription

    @Test func channelsDescriptionMono() {
        let props = AudioFormatProperties(channelCount: 1, sampleRate: 44100, duration: 1.0)
        #expect(props.channelsDescription == "Mono")
    }

    @Test func channelsDescriptionStereo() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 1.0)
        #expect(props.channelsDescription == "Stereo")
    }

    @Test func channelsDescriptionMulti() {
        let props = AudioFormatProperties(channelCount: 6, sampleRate: 48000, duration: 1.0)
        #expect(props.channelsDescription == "6 Channel")
    }

    @Test func channelsDescriptionZero() {
        let props = AudioFormatProperties(channelCount: 0, sampleRate: 44100, duration: 1.0)
        #expect(props.channelsDescription == "")
    }

    // MARK: - bitRateDescription

    @Test func bitRateDescription() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, bitRate: 320, duration: 1.0)
        #expect(props.bitRateDescription == "320 kbit/s")
    }

    @Test func bitRateDescriptionNil() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 1.0)
        #expect(props.bitRateDescription == "")
    }

    @Test func bitRateDescriptionZero() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, bitRate: 0, duration: 1.0)
        #expect(props.bitRateDescription == "")
    }

    // MARK: - formatDescription

    @Test func formatDescriptionBasic() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, bitsPerChannel: 16, duration: 1.0)
        let desc = props.formatDescription
        #expect(desc.contains("44.1 kHz"))
        #expect(desc.contains("16 bit"))
        #expect(desc.contains("Stereo"))
    }

    @Test func formatDescriptionWithBitRate() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 48000, bitRate: 128, duration: 1.0)
        let desc = props.formatDescription
        #expect(desc.contains("48 kHz"))
        #expect(desc.contains("128 kbit/s"))
        #expect(desc.contains("Stereo"))
    }

    @Test func formatDescriptionNonStandardRate() {
        // 22050 / 1000 = 22.05, truncated to 1 decimal = 22.0, formatted as integer "22"
        let props = AudioFormatProperties(channelCount: 1, sampleRate: 22050, duration: 1.0)
        let desc = props.formatDescription
        #expect(desc.contains("22 kHz"))
        #expect(desc.contains("Mono"))
    }

    // MARK: - durationDescription

    @Test func durationDescription() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 65.5)
        #expect(!props.durationDescription.isEmpty)
    }

    @Test func durationDescriptionZero() {
        let props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 0)
        #expect(!props.durationDescription.isEmpty)
    }

    // MARK: - update(bitRate:)

    @Test func updateBitRate() {
        var props = AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 1.0)
        #expect(props.bitRateDescription == "")

        props.update(bitRate: 256)
        #expect(props.bitRateDescription == "256 kbit/s")
        #expect(props.formatDescription.contains("256 kbit/s"))
    }

    // MARK: - Codable

    @Test func codableRoundTrip() throws {
        let original = AudioFormatProperties(
            channelCount: 2,
            sampleRate: 48000,
            bitsPerChannel: 24,
            bitRate: 1536,
            duration: 120.5
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioFormatProperties.self, from: data)

        #expect(decoded.channelCount == original.channelCount)
        #expect(decoded.sampleRate == original.sampleRate)
        #expect(decoded.bitsPerChannel == original.bitsPerChannel)
        #expect(decoded.bitRate == original.bitRate)
        #expect(decoded.duration == original.duration)

        // descriptions should be reconstructed
        #expect(!decoded.formatDescription.isEmpty)
        #expect(!decoded.channelsDescription.isEmpty)
    }

    @Test func codableOptionalFields() throws {
        let original = AudioFormatProperties(channelCount: 1, sampleRate: 44100, duration: 5.0)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioFormatProperties.self, from: data)

        #expect(decoded.bitsPerChannel == nil)
        #expect(decoded.bitRate == nil)
    }

    // MARK: - Hashable

    @Test func hashable() {
        let a = AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 1.0)
        let b = AudioFormatProperties(channelCount: 2, sampleRate: 44100, duration: 1.0)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
