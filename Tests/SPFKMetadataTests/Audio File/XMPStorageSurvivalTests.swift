// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

/// A tag save leaves the file's stored XMP packet byte-identical: WAV `_PMX`, AIFF `APPL`/`XMP `,
/// and the MP3 ID3v2 `PRIV` frame owned by `XMP`.
@Suite(.tags(.file))
final class XMPStorageSurvivalTests: BinTestCase {
    private let packet = Data(
        #"<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?><x:xmpmeta xmlns:x="adobe:ns:meta/"/><?xpacket end="w"?>  "#.utf8
    )

    @Test func aWaveTagSaveKeepsThePMXChunk() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        try IFFChunks.append(id: "_PMX", payload: packet, to: url, bigEndian: false)
        #expect(try IFFChunks.payload(id: "_PMX", in: url, bigEndian: false) == packet)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Saved Title")
        try description.save(dirtyFlags: [.metadata])

        #expect(try IFFChunks.payload(id: "_PMX", in: url, bigEndian: false) == packet)
    }

    @Test func anAIFFTagSaveKeepsTheXMPApplicationChunk() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        let payload = Data("XMP ".utf8) + packet
        try IFFChunks.append(id: "APPL", payload: payload, to: url, bigEndian: true)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Saved Title")
        try description.save(dirtyFlags: [.metadata])

        #expect(try IFFChunks.payload(id: "APPL", in: url, bigEndian: true) == payload)
    }

    @Test func anMP3TagSaveKeepsTheXMPPrivateFrame() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_xmp)
        let original = try #require(try ID3PrivateFrames.xmpPacket(in: url))

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Saved Title")
        try description.save(dirtyFlags: [.metadata])

        let saved = try ID3PrivateFrames.xmpPacket(in: url)
        #expect(saved == original)
    }
}

// MARK: - Raw readers

/// RIFF (little-endian sizes) or IFF/AIFF (big-endian) top-level chunks.
enum IFFChunks {
    static func append(id: String, payload: Data, to url: URL, bigEndian: Bool) throws {
        var data = try Data(contentsOf: url)
        data.append(Data(id.utf8))
        data.append(encode(UInt32(payload.count), bigEndian: bigEndian))
        data.append(payload)
        if payload.count.isMultiple(of: 2) == false { data.append(0) }
        data.replaceSubrange(4 ..< 8, with: encode(UInt32(data.count - 8), bigEndian: bigEndian))
        try data.write(to: url)
    }

    static func payload(id: String, in url: URL, bigEndian: Bool) throws -> Data? {
        let data = try Data(contentsOf: url)
        var offset = 12

        while offset + 8 <= data.count {
            let chunkID = String(decoding: data[offset ..< offset + 4], as: UTF8.self)
            let size = Int(decode(data, at: offset + 4, bigEndian: bigEndian))
            let body = offset + 8
            guard body + size <= data.count else { return nil }

            if chunkID == id { return Data(data[body ..< body + size]) }

            offset = body + size + (size & 1)
        }

        return nil
    }

    private static func encode(_ value: UInt32, bigEndian: Bool) -> Data {
        withUnsafeBytes(of: bigEndian ? value.bigEndian : value.littleEndian) { Data($0) }
    }

    private static func decode(_ data: Data, at offset: Int, bigEndian: Bool) -> UInt32 {
        let bytes = data[offset ..< offset + 4].map(UInt32.init)
        return bigEndian
            ? bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3]
            : bytes[3] << 24 | bytes[2] << 16 | bytes[1] << 8 | bytes[0]
    }
}

/// The ID3v2 `PRIV` frame whose owner is `XMP`, from the tag at the start of the file.
enum ID3PrivateFrames {
    static func xmpPacket(in url: URL) throws -> Data? {
        let data = try Data(contentsOf: url)
        guard data.count >= 10, data.starts(with: Data("ID3".utf8)) else { return nil }

        let version = data[3]
        let tagEnd = 10 + syncsafe(data, at: 6)
        var offset = 10

        while offset + 10 <= min(tagEnd, data.count) {
            let frameID = String(decoding: data[offset ..< offset + 4], as: UTF8.self)
            guard frameID.first?.isLetter == true || frameID.first?.isNumber == true else { return nil }

            let size = version >= 4 ? syncsafe(data, at: offset + 4) : bigEndian(data, at: offset + 4)
            let body = offset + 10
            guard body + size <= data.count else { return nil }

            if frameID == "PRIV" {
                let frame = Data(data[body ..< body + size])
                let owner = Data("XMP".utf8) + Data([0])
                if frame.starts(with: owner) { return frame.dropFirst(owner.count) }
            }

            offset = body + size
        }

        return nil
    }

    private static func syncsafe(_ data: Data, at offset: Int) -> Int {
        (0 ..< 4).reduce(0) { $0 << 7 | Int(data[offset + $1] & 0x7F) }
    }

    private static func bigEndian(_ data: Data, at offset: Int) -> Int {
        (0 ..< 4).reduce(0) { $0 << 8 | Int(data[offset + $1]) }
    }
}
