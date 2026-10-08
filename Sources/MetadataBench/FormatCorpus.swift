// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation

/// The other formats the save path writes, each as an encoder leaves a fresh file: no tags, no
/// artwork, whatever padding the encoder reserves. FLAC and M4A are encoded through Core Audio,
/// which needs the process outside the sandbox; the rest are written byte by byte.
enum BenchFormat: String, CaseIterable {
    case mp3
    case flac
    case m4a
    case aiff = "aif"
    /// AIFF with an `ID3 ` chunk ahead of `SSND`, where a tag save that appends it moves the audio.
    case aiffLeadingID3 = "aif-id3"
    case ogg
    case opus
    case mka

    var pathExtension: String {
        self == .aiffLeadingID3 ? BenchFormat.aiff.rawValue : rawValue
    }
}

struct FormatCorpus {
    let directory: URL
    /// 48 kHz stereo, the same duration as the WAV corpus's audio.
    let seconds: Int

    init(directory: URL, pcmBytes: Int) {
        self.directory = directory
        seconds = max(1, pcmBytes / (48000 * 4))
    }

    func write(_ format: BenchFormat) throws -> URL {
        let url = directory.appendingPathComponent("master-\(format.rawValue).\(format.pathExtension)")
        try? FileManager.default.removeItem(at: url)

        switch format {
        case .mp3: try writeMP3(to: url)
        case .aiff: try writeAIFF(to: url, leadingID3: false)
        case .aiffLeadingID3: try writeAIFF(to: url, leadingID3: true)
        case .ogg: try OggCorpus(seconds: seconds).writeVorbis(to: url)
        case .opus: try OggCorpus(seconds: seconds).writeOpus(to: url)
        case .mka: try MatroskaCorpus(seconds: seconds).write(to: url)
        case .flac: try encode(to: url, settings: [AVFormatIDKey: kAudioFormatFLAC, AVEncoderBitDepthHintKey: 16])
        case .m4a: try encode(to: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC])
        }
        return url
    }

    /// Silent MPEG-1 Layer III frames: 128 kbps, 48 kHz, stereo, no CRC — 384 bytes and 1,152
    /// samples each.
    private func writeMP3(to url: URL) throws {
        let frame = Data([0xFF, 0xFB, 0x94, 0x00]) + Data(count: 380)
        let frameCount = seconds * 48000 / 1152
        let block = Data((0 ..< 1000).flatMap { _ in frame })

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        var remaining = frameCount
        while remaining > 0 {
            let count = min(remaining, 1000)
            try handle.write(contentsOf: block.prefix(count * frame.count))
            remaining -= count
        }
    }

    /// `COMM`, then `ID3 ` when `leadingID3`, then `SSND` holding 16-bit stereo noise.
    private func writeAIFF(to url: URL, leadingID3: Bool) throws {
        let frames = seconds * 48000
        let audioBytes = frames * 4
        let sampleRate48k = Data([0x40, 0x0E, 0xBB, 0x80, 0, 0, 0, 0, 0, 0])
        let comm = be16(2) + be32(UInt32(frames)) + be16(16) + sampleRate48k
        let id3 = leadingID3 ? try beChunk("ID3 ", WAVCorpus.id3Tag(artwork: nil)) : Data()
        let ssndHeader = Data("SSND".utf8) + be32(UInt32(8 + audioBytes)) + be32(0) + be32(0)
        let formSize = 4 + 8 + comm.count + id3.count + ssndHeader.count + audioBytes

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        try handle.write(contentsOf: Data("FORM".utf8) + be32(UInt32(formSize)) + Data("AIFF".utf8))
        try handle.write(contentsOf: beChunk("COMM", comm) + id3 + ssndHeader)
        try WAVCorpus.writeAudio(byteCount: audioBytes, to: handle)
    }

    /// Noise, so a lossless encoder cannot shrink the file below its PCM size.
    private func encode(to url: URL, settings: [String: Any]) throws {
        var settings = settings
        settings[AVSampleRateKey] = 48000
        settings[AVNumberOfChannelsKey] = 2

        let file = try AVAudioFile(forWriting: url, settings: settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 48000),
              let channels = buffer.floatChannelData
        else { throw BenchError("could not allocate an encode buffer") }

        buffer.frameLength = 48000
        var state: UInt32 = 0x2468_ACE0

        for _ in 0 ..< seconds {
            for channel in 0 ..< 2 {
                for index in 0 ..< 48000 {
                    state = state &* 1_664_525 &+ 1_013_904_223
                    channels[channel][index] = Float(Int32(bitPattern: state)) / Float(Int32.max) * 0.5
                }
            }
            try file.write(from: buffer)
        }
    }
}

/// An IFF chunk with a big-endian size, padded to an even length.
func beChunk(_ id: String, _ payload: Data) -> Data {
    var data = Data(id.utf8) + be32(UInt32(payload.count)) + payload
    if payload.count.isMultiple(of: 2) == false { data.append(0) }
    return data
}

func be16(_ value: Int) -> Data {
    withUnsafeBytes(of: UInt16(truncatingIfNeeded: value).bigEndian) { Data($0) }
}

func be32(_ value: UInt32) -> Data {
    withUnsafeBytes(of: value.bigEndian) { Data($0) }
}
