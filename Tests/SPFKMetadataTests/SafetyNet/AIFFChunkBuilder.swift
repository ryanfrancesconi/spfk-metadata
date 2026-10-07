// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// Rewrites an AIFF or AIFF-C file's chunk list, for planting what another application would
/// have written. Chunks the edit leaves alone keep their bytes and order.
enum AIFFChunkBuilder {
    typealias Chunk = AIFFChunks.Chunk

    /// Reads the file's chunks, hands them to `edit`, and writes the result with every size
    /// recomputed.
    static func rewrite(_ url: URL, _ edit: (inout [Chunk]) throws -> Void) throws {
        let aiff = try AIFFChunks(contentsOf: url)
        var chunks = aiff.chunks
        try edit(&chunks)

        let body = Data(aiff.formType.utf8) + encode(chunks)
        try (Data("FORM".utf8) + be32(body.count) + body).write(to: url)
    }

    /// Each chunk as ID, big-endian size, payload and, for an odd size, a pad byte.
    static func encode(_ chunks: [Chunk]) -> Data {
        chunks.reduce(into: Data()) { data, chunk in
            data += Data(chunk.id.utf8) + be32(chunk.payload.count) + chunk.payload
            if chunk.payload.count.isMultiple(of: 2) == false { data.append(0) }
        }
    }

    static func be32(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt32(value).bigEndian) { Data($0) }
    }

    static func be16(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt16(truncatingIfNeeded: value).bigEndian) { Data($0) }
    }
}
