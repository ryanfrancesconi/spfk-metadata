// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// What other applications put in an AIFF, as each would write it.
enum SafetyNetAIFFForeign {
    static let textChunkIDs = ["NAME", "AUTH", "ANNO", "(c) "]

    static let textChunks: [AIFFChunks.Chunk] = [
        AIFFChunks.Chunk(id: "NAME", payload: Data("Another App's Name".utf8)),
        AIFFChunks.Chunk(id: "AUTH", payload: Data("Another App's Author".utf8)),
        AIFFChunks.Chunk(id: "ANNO", payload: Data("Annotated by another app".utf8)),
        AIFFChunks.Chunk(id: "(c) ", payload: Data("2026 Another App".utf8)),
    ]

    /// One comment, tied to no marker, so a marker save has no reason to touch it.
    static let comments = AIFFChunks.Chunk(
        id: "COMT",
        payload: AIFFChunkBuilder.be16(1) + AIFFChunkBuilder.be32(3_870_000_000) + AIFFChunkBuilder.be16(0)
            + AIFFChunkBuilder.be16(25) + Data("A comment another app put".utf8) + Data([0])
    )

    /// `XMP ` as spfk-metadata-xmp writes it, and another application's.
    static let applicationSignatures = ["XMP ", "SNet"]

    static let applications: [AIFFChunks.Chunk] = [
        AIFFChunks.Chunk(id: "APPL", payload: Data("XMP ".utf8) + Data(SafetyNetSetup.xmpPacket(title: "Another App").utf8)),
        AIFFChunks.Chunk(id: "APPL", payload: Data("SNet".utf8) + Data([0x53, 0x4E, 0x00, 0xFF, 0x01, 0x02])),
    ]
}

enum SafetyNetAIFFPlant {
    enum PlantError: Error {
        case noTag(URL)
    }

    /// Re-renders the setup save's `ID3 ` chunk as ID3v2.3 with the foreign frames planted, and
    /// adds the text, comment and application chunks.
    static func plant(in url: URL) throws {
        try AIFFChunkBuilder.rewrite(url) { chunks in
            guard let index = chunks.firstIndex(where: { $0.id == "ID3 " || $0.id == "id3 " }),
                  let tag = try ID3v2Frames.tag(in: chunks[index].payload)
            else { throw PlantError.noTag(url) }

            let frames = try SafetyNetID3Plant.plantedFrames(from: tag.frames, majorVersion: tag.majorVersion)
            chunks[index] = AIFFChunks.Chunk(id: "ID3 ", payload: ID3v24TagBuilder.version3Tag(frames: frames))

            chunks += SafetyNetAIFFForeign.textChunks + [SafetyNetAIFFForeign.comments] + SafetyNetAIFFForeign.applications
        }
    }
}
