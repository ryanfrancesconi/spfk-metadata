import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

// MARK: - Malformed WAV investigation

#if os(macOS)
    /// Development tests to characterise how AVAudioFile and MetaAudioFileDescription behave
    /// with a WAV that has a wrong RIFF chunk size (data chunk outside declared boundary).
    @Suite(.tags(.development)) struct MalformedWAVInvestigationTests {
        let url = URL(filePath: "/Users/rf/Downloads/TestResources/invalid-chunk-size.wav")

        /// AVAudioFile opens without error but reports 0 frames — the data chunk lies outside
        /// the declared RIFF boundary so AVFoundation never finds it.
        @Test func avAudioFileReportsZeroFrames() throws {
            guard url.exists else { return }

            let audioFile = try AVAudioFile(forReading: url)
            #expect(audioFile.length == 0)
            #expect(audioFile.duration == 0.0)
            // Format header is still readable
            #expect(audioFile.fileFormat.sampleRate == 44100.0)
            #expect(audioFile.fileFormat.channelCount == 2)
        }

        /// MetaAudioFileDescription reads correct metadata via TagLib but marks the file
        /// as not AV-playable because AVAudioFile reports 0 frames.
        @Test func metaAudioFileDescriptionIsNotPlayable() async throws {
            guard url.exists else { return }

            let desc = try await MetaAudioFileDescription(parsing: url)
            // TagLib reads past the bad RIFF boundary — format properties are correct
            #expect(desc.audioFormat?.sampleRate == 44100.0)
            #expect(desc.audioFormat?.channelCount == 2)
            #expect((desc.audioFormat?.duration ?? 0) > 0)
            // AVAudioFile sees 0 frames — not playable
            #expect(desc.isAVPlayable == false)
        }
    }
#endif
