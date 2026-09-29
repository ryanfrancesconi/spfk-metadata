// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKMetadataBase
import SPFKVideo

extension MetaAudioFileDescription {
    /// Which stack `init(parsing:)` reads a file through, and so where its format and length come from.
    enum ParseRoute {
        /// Everything through TagLib; `AVAudioFile` only measures the length.
        case wave(frameCount: AVAudioFramePosition)

        case audioFile(AVAudioFile)

        /// `AVAudioFile` refused a container TagLib claims (Matroska). The format comes from TagLib;
        /// without it, `error` stands.
        case tagStore(error: any Error)

        /// Only `AVAsset` reads it (MXF); MediaToolbox readers don't serve `AVAudioFile`.
        case asset(AudioTrackFormat)

        /// Gated on the format's own `supportsMetadata`, not a list of containers.
        init(url: URL, fileType: AudioFileType?) async throws {
            if fileType == .wav {
                self = .wave(frameCount: (try? AVAudioFile(forReading: url))?.length ?? 0)
                return
            }

            do {
                self = try .audioFile(AVAudioFile(forReading: url))
            } catch {
                if fileType?.supportsMetadata == true {
                    self = .tagStore(error: error)
                } else if let format = await AudioTrackReader.format(of: url) {
                    self = .asset(format)
                } else {
                    throw error
                }
            }
        }

        /// `nil` where the format is read later, from TagLib.
        var audioFormat: AudioFormatProperties? {
            switch self {
            case .wave, .tagStore:
                nil
            case let .audioFile(audioFile):
                AudioFormatProperties(audioFile: audioFile)
            case let .asset(format):
                AudioFormatProperties(
                    channelCount: format.channelCount,
                    sampleRate: format.sampleRate,
                    bitsPerChannel: format.bitsPerChannel,
                    duration: format.duration
                )
            }
        }

        /// Frames AVFoundation can play; 0 when it cannot.
        var frameCount: AVAudioFramePosition {
            switch self {
            case let .wave(frameCount): frameCount
            case let .audioFile(audioFile): audioFile.length
            case .tagStore: 0
            case let .asset(format): format.frameCount
            }
        }
    }
}
