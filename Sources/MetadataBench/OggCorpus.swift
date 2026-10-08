// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// Ogg Opus and Ogg Vorbis files, paged as ffmpeg pages them: each header group on a page of its
/// own, then about a second of audio packets per page. Core Audio has no Ogg encoder, so the
/// packets are noise behind a valid header; nothing in a metadata save decodes them.
struct OggCorpus {
    let seconds: Int

    private static let vendor = Data("spfk-metadata-bench".utf8)

    /// A vendor string and no comments, as an encoder leaves it.
    private static let commentFields = le32(vendor.count) + vendor + le32(0)

    func writeOpus(to url: URL) throws {
        let preSkip = 312
        var head = Data("OpusHead".utf8) + Data([1, 2])
        head += le16(preSkip) + le32(48000) + le16(0) + Data([0])
        let tags = Data("OpusTags".utf8) + Self.commentFields

        // 20 ms CELT fullband stereo frames (TOC 0xFC) of 320 bytes: 128 kbps.
        try write(to: url, headers: [[head], [tags]], packetBytes: 320, packetFrames: 960, firstByte: 0xFC, granuleOffset: preSkip)
    }

    func writeVorbis(to url: URL) throws {
        // Blocksizes 256 and 2048; 128 kbps nominal.
        var identification = Data([1]) + Data("vorbis".utf8) + le32(0) + Data([2])
        identification += le32(48000) + le32(0) + le32(128_000) + le32(0)
        identification += Data([0xB8, 1])
        let comment = Data([3]) + Data("vorbis".utf8) + Self.commentFields + Data([1])

        // The size libvorbis's codebooks take; their content is never read.
        var noise = NoiseSource()
        let setup = Data([5]) + Data("vorbis".utf8) + noise.bytes(3800)

        // Long-block packets of 1,024 samples at 128 kbps.
        try write(to: url, headers: [[identification], [comment, setup]], packetBytes: 341, packetFrames: 1024, firstByte: 0, granuleOffset: 0)
    }

    private func write(to url: URL, headers: [[Data]], packetBytes: Int, packetFrames: Int, firstByte: UInt8, granuleOffset: Int) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        var pages = OggPageWriter(handle: handle)

        for (index, packets) in headers.enumerated() {
            try pages.write(packets, granule: 0, headerType: index == 0 ? 0x02 : 0)
        }

        let total = seconds * 48000 / packetFrames
        let perPage = 48000 / packetFrames
        var noise = NoiseSource()
        var written = 0

        while written < total {
            let count = min(perPage, total - written)
            let packets = (0 ..< count).map { _ in Data([firstByte]) + noise.bytes(packetBytes - 1) }
            written += count
            try pages.write(packets, granule: UInt64(granuleOffset + written * packetFrames), headerType: written == total ? 0x04 : 0)
        }
    }
}

/// One logical stream's pages, numbered and checksummed.
private struct OggPageWriter {
    let handle: FileHandle
    let serialNumber: UInt32 = 0x5350_464B
    var sequenceNumber: UInt32 = 0

    mutating func write(_ packets: [Data], granule: UInt64, headerType: UInt8) throws {
        let lacing = packets.flatMap { [UInt8](repeating: 255, count: $0.count / 255) + [UInt8($0.count % 255)] }
        guard lacing.count <= 255 else { throw BenchError("an Ogg page holds at most 255 segments") }

        var page = Data("OggS".utf8) + Data([0, headerType]) + le64(granule)
        page += le32(serialNumber) + le32(sequenceNumber) + le32(0)
        page += Data([UInt8(lacing.count)]) + Data(lacing)
        for packet in packets {
            page += packet
        }
        page.replaceSubrange(22 ..< 26, with: le32(Self.crc(page)))

        try handle.write(contentsOf: page)
        sequenceNumber += 1
    }

    /// CRC-32, polynomial 0x04C11DB7, unreflected, zero initial value: Ogg's own.
    private static let table: [UInt32] = (0 ..< 256).map { index in
        var value = UInt32(index) << 24
        for _ in 0 ..< 8 {
            value = value & 0x8000_0000 != 0 ? (value << 1) ^ 0x04C1_1DB7 : value << 1
        }
        return value
    }

    private static func crc(_ data: Data) -> UInt32 {
        data.reduce(UInt32(0)) { crc, byte in
            (crc << 8) ^ table[Int((crc >> 24) ^ UInt32(byte))]
        }
    }
}

/// The WAV corpus's patterned bytes, drawn in arbitrary lengths.
struct NoiseSource {
    private var state: UInt64 = 0x9E37_79B9_7F4A_7C15

    mutating func bytes(_ count: Int) -> Data {
        var words = [UInt64](repeating: 0, count: (count + 7) / 8)
        for index in words.indices {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            words[index] = state
        }
        return words.withUnsafeBytes { Data($0.prefix(count)) }
    }
}
