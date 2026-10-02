// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// Rewrites a little-endian RIFF file's chunk list, for planting what another application would
/// have written. Chunks the edit leaves alone keep their bytes and order.
enum RIFFChunkBuilder {
    typealias Chunk = RIFFChunks.Chunk

    /// Reads the file's chunks, hands them to `edit`, and writes the result with every size
    /// recomputed.
    static func rewrite(_ url: URL, _ edit: (inout [Chunk]) throws -> Void) throws {
        let riff = try RIFFChunks(contentsOf: url)
        var chunks = riff.chunks
        try edit(&chunks)

        let body = Data(riff.formType.utf8) + encode(chunks)
        try (Data("RIFF".utf8) + le32(body.count) + body).write(to: url)
    }

    /// Each chunk as ID, size, payload and, for an odd size, a pad byte.
    static func encode(_ chunks: [Chunk]) -> Data {
        chunks.reduce(into: Data()) { data, chunk in
            data += Data(chunk.id.utf8) + le32(chunk.payload.count) + chunk.payload
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

    static func le16(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian) { Data($0) }
    }
}
