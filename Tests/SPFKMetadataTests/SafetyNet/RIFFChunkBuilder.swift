// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// Rewrites a little-endian RIFF file's chunk list, for planting what another application would
/// have written. Chunks the edit leaves alone keep their bytes and order.
enum RIFFChunkBuilder {
    typealias Chunk = RIFFChunks.Chunk

    /// Reads the file's chunks, hands them to `edit`, and writes the result with every size
    /// recomputed. An RF64 or BW64 file stays one, its `ds64` sizes updated.
    static func rewrite(_ url: URL, _ edit: (inout [Chunk]) throws -> Void) throws {
        let riff = try RIFFChunks(contentsOf: url)
        var chunks = riff.chunks
        try edit(&chunks)
        try write(chunks, formType: riff.formType, form: riff.form, sampleCount: riff.longFormSizes?.sampleCount, to: url)
    }

    /// Turns a `RIFF` WAVE into `form` (`RF64` or `BW64`) as a recorder writes one: the magic, a
    /// `ds64` first, and the sentinel in both 32-bit sizes it replaces. Core Audio writes the long
    /// form only past 4 GiB, so a small one has to be made this way.
    static func convertToLongForm(_ url: URL, form: String = "RF64") throws {
        let riff = try RIFFChunks(contentsOf: url)
        guard !riff.isLongForm, let format = riff.first("fmt "), format.payload.count >= 14 else { throw MissingChunk() }

        let blockAlign = Int(format.payload[format.payload.startIndex + 12]) | Int(format.payload[format.payload.startIndex + 13]) << 8
        let dataSize = try riff.first("data").map(\.payload.count) ?? { throw MissingChunk() }()
        let ds64 = Chunk(id: "ds64", payload: Data(count: 28))

        try write([ds64] + riff.chunks, formType: riff.formType, form: form, sampleCount: UInt64(dataSize / max(blockAlign, 1)), to: url)
    }

    /// `sampleCount` is kept in `ds64`; it is nil for a `RIFF` file.
    private static func write(_ chunks: [Chunk], formType: String, form: String, sampleCount: UInt64?, to url: URL) throws {
        guard form != "RIFF" else {
            let body = Data(formType.utf8) + encode(chunks)
            try (Data("RIFF".utf8) + le32(body.count) + body).write(to: url)
            return
        }

        let dataSize = chunks.first { $0.id == "data" }?.payload.count ?? 0
        let unsized = Data(formType.utf8) + encode(chunks, longForm: true)
        let ds64 = le64(UInt64(unsized.count)) + le64(UInt64(dataSize)) + le64(sampleCount ?? 0) + le32(0)

        var sized = chunks
        try replace(in: &sized, where: { $0.id == "ds64" }, with: Chunk(id: "ds64", payload: ds64))

        let body = Data(formType.utf8) + encode(sized, longForm: true)
        try (Data(form.utf8) + le32(Int(RIFFChunks.longFormSizeSentinel)) + body).write(to: url)
    }

    /// Each chunk as ID, size, payload and, for an odd size, a pad byte. In a long-form file the
    /// `data` chunk's size is the sentinel.
    static func encode(_ chunks: [Chunk], longForm: Bool = false) -> Data {
        chunks.reduce(into: Data()) { data, chunk in
            let size = longForm && chunk.id == "data" ? Int(RIFFChunks.longFormSizeSentinel) : chunk.payload.count
            data += Data(chunk.id.utf8) + le32(size) + chunk.payload
            if chunk.payload.count.isMultiple(of: 2) == false { data.append(0) }
        }
    }

    /// A `LIST` of `type` holding `subchunks`.
    static func list(_ type: String, _ subchunks: [Chunk]) -> Chunk {
        Chunk(id: "LIST", payload: Data(type.utf8) + encode(subchunks))
    }

    /// Replaces the first chunk matching `match`; throws when there is none.
    static func replace(in chunks: inout [Chunk], where match: (Chunk) -> Bool, with chunk: Chunk) throws {
        guard let index = chunks.firstIndex(where: match) else { throw MissingChunk() }
        chunks[index] = chunk
    }

    struct MissingChunk: Error {}

    static func le32(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) }
    }

    static func le64(_ value: UInt64) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func le16(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian) { Data($0) }
    }
}
