// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// Rewrites a FLAC file's metadata blocks, for planting what another application would have
/// written. Blocks the edit leaves alone keep their bytes and order; the audio is untouched.
enum FLACBlockWriter {
    typealias Block = FLACBlocks.Block

    /// Reads the file's blocks, hands them to `edit`, and writes the result with the last-block
    /// flag on the final block only.
    static func rewrite(_ url: URL, _ edit: (inout [Block]) throws -> Void) throws {
        let flac = try FLACBlocks(contentsOf: url)
        var blocks = flac.blocks
        try edit(&blocks)

        var data = flac.prefix + Data("fLaC".utf8)

        for (index, block) in blocks.enumerated() {
            let last: UInt8 = index == blocks.count - 1 ? 0x80 : 0
            data.append(last | block.type)
            data += be(block.payload.count, bytes: 3) + block.payload
        }

        try (data + flac.audio).write(to: url)
    }

    /// A `VORBIS_COMMENT` payload from an ordered field list.
    static func vorbisComment(vendor: String, fields: [VorbisComment.Field]) -> Block {
        func string(_ value: String) -> Data {
            let bytes = Data(value.utf8)
            return RIFFChunkBuilder.le32(bytes.count) + bytes
        }

        let body = string(vendor) + RIFFChunkBuilder.le32(fields.count) + fields.map { string("\($0.key)=\($0.value)") }.reduce(Data(), +)
        return Block(.vorbisComment, payload: body)
    }

    /// A `PICTURE` block. Width, height, depth and color count are left 0 (unknown).
    static func picture(type: UInt32, mimeType: String, description: String, data: Data) -> Block {
        let mime = Data(mimeType.utf8)
        let text = Data(description.utf8)

        let body = be(Int(type), bytes: 4) + be(mime.count, bytes: 4) + mime + be(text.count, bytes: 4) + text
            + Data(count: 16) + be(data.count, bytes: 4) + data
        return Block(.picture, payload: body)
    }

    /// An `APPLICATION` block.
    static func application(id: String, data: Data) -> Block {
        Block(.application, payload: Data(id.utf8) + data)
    }

    /// An `APPLICATION` block wrapping one RIFF chunk, as `flac --keep-foreign-metadata` stores it.
    static func riff(id: String, payload: Data) -> Block {
        application(id: "riff", data: Data(id.utf8) + RIFFChunkBuilder.le32(payload.count) + payload)
    }

    /// A non-CD `CUESHEET`: one track with one index at sample 0, then the lead-out at
    /// `leadOut`.
    static func cueSheet(catalog: String, leadOut: UInt64) -> Block {
        func track(offset: UInt64, number: UInt8, isrc: String, indexes: [(offset: UInt64, number: UInt8)]) -> Data {
            let isrcBytes = Data(isrc.utf8) + Data(count: 12 - isrc.utf8.count)
            let indexBytes = indexes.map { be(Int($0.offset), bytes: 8) + Data([$0.number, 0, 0, 0]) }.reduce(Data(), +)
            return be(Int(offset), bytes: 8) + Data([number]) + isrcBytes + Data(count: 14) + Data([UInt8(indexes.count)]) + indexBytes
        }

        let body = Data(catalog.utf8) + Data(count: 128 - catalog.utf8.count)
            + Data(count: 8) // lead-in: 0 for a non-CD sheet
            + Data(count: 259) // the CD flag clear, then reserved bytes
            + Data([2])
            + track(offset: 0, number: 1, isrc: "USSNT2600001", indexes: [(0, 1)])
            + track(offset: leadOut, number: 255, isrc: "", indexes: [])
        return Block(.cueSheet, payload: body)
    }

    static func be(_ value: Int, bytes: Int) -> Data {
        Data((0 ..< bytes).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
    }
}
