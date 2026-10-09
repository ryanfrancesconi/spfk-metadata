// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A WAV's frame count from its `fmt ` and `data` chunks is the length `AVAudioFile` reads, and is
/// given only for files whose structure leaves no room for Core Audio to read them differently.
@Suite(.tags(.file))
final class WaveFrameCountTests: BinTestCase {
    static let fixtures: [URL] = {
        let resources = TestBundleResources.shared
        return [
            resources.tabla_wav, resources.tabla_6_channel, resources.cowbell_wav, resources.cowbell_bext_wav,
            resources.pink_noise, resources.ixml_chunk, resources.wav_bext_v1, resources.wav_bext_v2,
            resources.wav_bext_v2b, resources.rated_80_wav,
        ]
    }()

    @Test(arguments: fixtures) func aFixtureCountsAsAVAudioFileReadsIt(url: URL) throws {
        #expect(try Self.frameCount(url) == AVAudioFile(forReading: url).length)
    }

    @Test(arguments: [SafetyNetRow.wav, .rf64, .wavRecorder, .wavUndatedBEXT])
    func aSafetyNetFileCountsAsAVAudioFileReadsIt(row: SafetyNetRow) async throws {
        deleteBinOnExit = true
        let url = try await row.prepare(in: bin)

        #expect(try Self.frameCount(url) == AVAudioFile(forReading: url).length)
    }

    static let writtenFormats: [(bits: Int, isFloat: Bool, channels: Int)] = [
        (8, false, 2), (16, false, 1), (16, false, 2), (24, false, 2), (32, false, 2),
        (32, true, 2), (64, true, 1), (24, false, 6), (32, true, 6),
    ]

    @Test(arguments: writtenFormats.indices) func aWrittenPCMFileCountsAsAVAudioFileReadsIt(index: Int) throws {
        deleteBinOnExit = true
        let format = Self.writtenFormats[index]
        let url = bin.appendingPathComponent("written-\(index).wav")

        try Self.write(to: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: format.bits,
            AVLinearPCMIsFloatKey: format.isFloat,
            AVNumberOfChannelsKey: format.channels,
        ])

        #expect(try Self.frameCount(url) == AVAudioFile(forReading: url).length)
        #expect(try Self.frameCount(url) == Self.writtenFrames)
    }

    @Test func anRF64FileCountsAsAVAudioFileReadsIt() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try RIFFChunkBuilder.convertToLongForm(url)

        #expect(try Self.frameCount(url) == AVAudioFile(forReading: url).length)
    }

    @Test(arguments: [kAudioFormatULaw, kAudioFormatALaw])
    func aCompressedFileIsLeftToCoreAudio(formatID: AudioFormatID) throws {
        deleteBinOnExit = true
        let url = bin.appendingPathComponent("compressed-\(formatID).wav")
        try Self.write(to: url, settings: [AVFormatIDKey: formatID, AVNumberOfChannelsKey: 1])

        #expect(try Self.frameCount(url) == -1)
    }

    @Test func aFileWithoutDataIsLeftToCoreAudio() throws {
        #expect(try Self.frameCount(TestBundleResources.shared.no_data_chunk) == -1)
    }

    /// Each one Core Audio reads differently from the chunk walk, or might.
    enum Malformation: String, CaseIterable {
        case formSizeShort, formSizeLong, formSizeZero, truncated, dataSizeLong, twoDataChunks, twoFormatChunks
        case blockAlignWrong, noChannels, extensibleOtherSubformat, garbageAfterLastChunk
    }

    @Test(arguments: Malformation.allCases) func aMalformedFileIsLeftToCoreAudio(_ malformation: Malformation) async throws {
        deleteBinOnExit = true
        let url = bin.appendingPathComponent("\(malformation.rawValue).wav")
        try Self.wave(malformation).write(to: url)

        #expect(try Self.frameCount(url) == -1)

        let avLength = (try? AVAudioFile(forReading: url))?.length ?? 0
        let description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.isAVPlayable == (avLength > 0))
    }

    @Test func aWellFormedHandBuiltFileIsCounted() throws {
        deleteBinOnExit = true
        let url = bin.appendingPathComponent("clean.wav")
        try Self.wave(nil).write(to: url)

        #expect(try Self.frameCount(url) == AVAudioFile(forReading: url).length)
        #expect(try Self.frameCount(url) == Int64(Self.audio.count / 4))
    }
}

extension WaveFrameCountTests {
    static func frameCount(_ url: URL) throws -> Int64 {
        let file = WaveFileC(path: url.path)
        try #require(file.loadTags())
        return file.frameCount
    }

    static let writtenFrames: Int64 = 4410

    static func write(to url: URL, settings: [String: Any]) throws {
        var settings = settings
        settings[AVSampleRateKey] = 44100
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(writtenFrames)))
        buffer.frameLength = buffer.frameCapacity
        try file.write(from: buffer)
    }

    /// 1,000 frames of 16-bit stereo.
    static let audio = Data((0 ..< 4000).map { UInt8(truncatingIfNeeded: $0 &* 7) })

    /// A 16-bit stereo WAV, malformed as named; well formed for nil.
    static func wave(_ malformation: Malformation?) -> Data {
        var format = le16(1) + le16(2) + le32(48000) + le32(48000 * 4) + le16(4) + le16(16)
        var body = chunk("fmt ", format) + chunk("data", audio)
        var formSize: UInt32?
        var tail = Data()

        switch malformation {
        case nil:
            break
        case .formSizeShort:
            formSize = UInt32(4 + body.count - audio.count / 2)
        case .formSizeLong:
            formSize = UInt32(4 + body.count + 100)
        case .formSizeZero:
            formSize = 0
        case .truncated:
            body.removeLast(audio.count / 2 + 1)
            formSize = UInt32(4 + body.count + audio.count / 2 + 1)
        case .dataSizeLong:
            body = chunk("fmt ", format) + Data("data".utf8) + le32(UInt32(audio.count * 2)) + audio
        case .twoDataChunks:
            body += chunk("data", audio.prefix(2000))
        case .twoFormatChunks:
            body = chunk("fmt ", format) + chunk("fmt ", le16(1) + le16(1) + le32(48000) + le32(48000 * 2) + le16(2) + le16(16)) + chunk("data", audio)
        case .blockAlignWrong:
            format.replaceSubrange(12 ..< 14, with: le16(8))
            body = chunk("fmt ", format) + chunk("data", audio)
        case .noChannels:
            format.replaceSubrange(2 ..< 4, with: le16(0))
            body = chunk("fmt ", format) + chunk("data", audio)
        case .extensibleOtherSubformat:
            // Ambisonic B-format's PCM GUID, not KSDATAFORMAT_SUBTYPE_PCM's.
            let guid = Data([0x01, 0, 0, 0, 0x21, 0x07, 0xD3, 0x11, 0x86, 0x44, 0xC8, 0xC1, 0xCA, 0, 0, 0])
            let extensible = le16(0xFFFE) + format.dropFirst(2) + le16(22) + le16(16) + le32(3) + guid
            body = chunk("fmt ", extensible) + chunk("data", audio)
        case .garbageAfterLastChunk:
            tail = Data([0xFF, 0xFE, 0x01])
        }

        return Data("RIFF".utf8) + le32(formSize ?? UInt32(4 + body.count)) + Data("WAVE".utf8) + body + tail
    }

    static func chunk(_ id: String, _ payload: Data) -> Data {
        var data = Data(id.utf8) + le32(UInt32(payload.count)) + payload
        if !payload.count.isMultiple(of: 2) { data.append(0) }
        return data
    }

    static func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    static func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
}
