// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKTesting

extension SafetyNetSnapshot {
    /// The audio, found without `spfk-metadata`: a WAV's `data` payload, a FLAC's frames after the
    /// metadata blocks, an MP3's frames between its ID3v2 and ID3v1 tags, and an MP4's audio decoded
    /// to PCM — its `mdat` also holds the chapter track's text, which a marker save rewrites. Nil for
    /// a container none of these recognize.
    func audioPayload(of data: Data) -> Data? {
        if let riff {
            return riff.first("data")?.payload
        }

        if let flac {
            return flac.audio
        }

        if mp4 != nil {
            return mp4AudioPCM
        }

        return Self.mpegFrames(in: data)
    }

    static func decodedPCM(of url: URL) throws -> Data {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: true)
        let capacity = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: max(capacity, 1)) else {
            return Data()
        }

        try file.read(into: buffer)

        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        return audioBuffer.mData.map { Data(bytes: $0, count: Int(audioBuffer.mDataByteSize)) } ?? Data()
    }

    /// The bytes after a leading ID3v2 tag (header, body and any footer) and before a trailing
    /// 128-byte ID3v1 tag. Nil when the file starts with neither a tag nor an MPEG frame sync.
    static func mpegFrames(in data: Data) -> Data? {
        let bytes = [UInt8](data)
        var start = 0

        if bytes.count >= 10, bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 {
            let size = bytes[6 ..< 10].reduce(0) { $0 << 7 | Int($1 & 0x7F) }
            let footer = bytes[5] & 0x10 != 0 ? 10 : 0
            start = 10 + size + footer
        }

        guard start + 2 <= bytes.count, bytes[start] == 0xFF, bytes[start + 1] & 0xE0 == 0xE0 else { return nil }

        var end = bytes.count
        if end - start >= 128, bytes[end - 128] == 0x54, bytes[end - 127] == 0x41, bytes[end - 126] == 0x47 {
            end -= 128
        }

        return Data(bytes[start ..< end])
    }
}
