// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// What other applications put in a WAV, as each would write it.
enum SafetyNetRIFFForeign {
    /// Not an `InfoFrameKey`.
    static let unknownInfoID = "IFRM"
    static let unknownInfoValue = "13"

    /// The base fixture's own chunks that no writer of ours knows.
    static let unknownChunkIDs = ["JUNK", "r64m", "smpl", "inst"]

    /// A `note` on the first cue point and a region `ltxt` on the second, beside the `labl`s.
    static let associatedData: [RIFFChunks.Chunk] = [
        RIFFChunks.Chunk(id: "note", payload: RIFFChunkBuilder.le32(0) + Data("A note another app wrote".utf8) + Data([0])),
        RIFFChunks.Chunk(
            id: "ltxt",
            payload: RIFFChunkBuilder.le32(1) + RIFFChunkBuilder.le32(4800) + Data("rgn ".utf8)
                + [0, 0, 0, 0].map(RIFFChunkBuilder.le16).reduce(Data(), +) + Data("Another app's region".utf8) + Data([0])
        ),
    ]

    /// A version 2 `bext` as a recorder writes it: every field set, with the setup's description
    /// and originator.
    static var broadcastExtension: Data {
        func text(_ string: String, _ size: Int) -> Data {
            let bytes = Data(string.utf8)
            return bytes + Data(count: size - bytes.count)
        }

        let umid = Data([0x06, 0x0A, 0x2B, 0x34, 0x01, 0x01, 0x01, 0x05, 0x01, 0x01, 0x0D, 0x20, 0x13, 0x00, 0x00, 0x00])
            + Data((0 ..< 48).map { UInt8(truncatingIfNeeded: $0 * 5 + 7) })
        let loudness = [-2301, 512, -101, -1500, -1800].map(RIFFChunkBuilder.le16).reduce(Data(), +)

        let fields: [Data] = [
            text(SafetyNetSetup.bextSequenceDescription, 256),
            text(SafetyNetSetup.bextOriginator, 32),
            text("USSNT1234567890123456789012345", 32),
            Data("2026-09-3012:34:56".utf8),
            RIFFChunkBuilder.le32(0x2345_6789), RIFFChunkBuilder.le32(1),
            RIFFChunkBuilder.le16(2),
            umid, loudness, Data(count: 180),
            Data("A=PCM,F=48000,W=24,M=stereo,T=SafetyNet Recorder\r\n".utf8),
        ]

        return fields.reduce(Data(), +)
    }

    /// ``broadcastExtension`` with OriginationDate and OriginationTime left empty (NULs), as
    /// recorders without a clock write them.
    static var broadcastExtensionWithoutDate: Data {
        var data = broadcastExtension
        data.replaceSubrange(320 ..< 338, with: Data(count: 18))
        return data
    }

    /// iXML from another recorder, holding the setup's project and a comment and CDATA section.
    static let iXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <BWFXML>
    <!-- Written by another recorder -->
    <IXML_VERSION>1.61</IXML_VERSION>
    <PROJECT>\(SafetyNetSetup.iXMLProject)</PROJECT>
    <NOTE>Setup</NOTE>
    <SPEED><MASTER_SPEED>24000/1001</MASTER_SPEED><TIMECODE_RATE>24000/1001</TIMECODE_RATE><TIMECODE_FLAG>NDF</TIMECODE_FLAG></SPEED>
    <TRACK_LIST><TRACK_COUNT>2</TRACK_COUNT>\
    <TRACK><CHANNEL_INDEX>1</CHANNEL_INDEX><INTERLEAVE_INDEX>1</INTERLEAVE_INDEX><NAME>Boom</NAME></TRACK>\
    <TRACK><CHANNEL_INDEX>2</CHANNEL_INDEX><INTERLEAVE_INDEX>2</INTERLEAVE_INDEX><NAME>Lav</NAME></TRACK></TRACK_LIST>
    <USER><![CDATA[Scene 12 <take 3>]]></USER>
    </BWFXML>
    """
}

enum SafetyNetRIFFPlant {
    enum PlantError: Error {
        case noTag(URL)
    }

    /// Replaces the setup save's `bext` and iXML with another recorder's, adds an unknown INFO
    /// item and `note`/`ltxt` beside the labels, and re-renders the `ID3 ` chunk as ID3v2.3 with
    /// the foreign frames planted.
    static func plant(in url: URL) throws {
        try RIFFChunkBuilder.rewrite(url) { chunks in
            try RIFFChunkBuilder.replace(in: &chunks, where: { $0.id == "bext" }, with: .init(id: "bext", payload: SafetyNetRIFFForeign.broadcastExtension))
            try RIFFChunkBuilder.replace(in: &chunks, where: { $0.id == "iXML" }, with: .init(id: "iXML", payload: Data(SafetyNetRIFFForeign.iXML.utf8)))

            let unknownInfo = RIFFChunks.Chunk(id: SafetyNetRIFFForeign.unknownInfoID, payload: Data((SafetyNetRIFFForeign.unknownInfoValue + "\0").utf8))
            try appendSubchunks([unknownInfo], toList: "INFO", in: &chunks)
            try appendSubchunks(SafetyNetRIFFForeign.associatedData, toList: "adtl", in: &chunks)

            guard let index = chunks.firstIndex(where: { $0.id == "ID3 " || $0.id == "id3 " }),
                  let tag = try ID3v2Frames.tag(in: chunks[index].payload)
            else { throw PlantError.noTag(url) }

            let frames = try SafetyNetID3Plant.plantedFrames(from: framesAsAnotherAppWroteThem(tag.frames), majorVersion: tag.majorVersion)
            chunks[index] = RIFFChunks.Chunk(id: "ID3 ", payload: ID3v24TagBuilder.version3Tag(frames: frames))
        }
    }

    /// Replaces the setup save's `bext` with one whose date and time are empty.
    static func plantUndatedBroadcastExtension(in url: URL) throws {
        try RIFFChunkBuilder.rewrite(url) { chunks in
            try RIFFChunkBuilder.replace(
                in: &chunks, where: { $0.id == "bext" },
                with: .init(id: "bext", payload: SafetyNetRIFFForeign.broadcastExtensionWithoutDate)
            )
        }
    }

    /// Moves `data` behind every other chunk, so the metadata precedes the audio as a field
    /// recorder writes it.
    static func plantRecorderLayout(in url: URL) throws {
        try RIFFChunkBuilder.rewrite(url) { chunks in
            guard let index = chunks.firstIndex(where: { $0.id == "data" }) else { throw RIFFChunkBuilder.MissingChunk() }
            chunks.append(chunks.remove(at: index))
        }
    }

    private static func appendSubchunks(_ subchunks: [RIFFChunks.Chunk], toList type: String, in chunks: inout [RIFFChunks.Chunk]) throws {
        guard let list = chunks.first(where: { $0.listType == type }) else { throw RIFFChunkBuilder.MissingChunk() }
        try RIFFChunkBuilder.replace(in: &chunks, where: { $0.listType == type }, with: RIFFChunkBuilder.list(type, list.subchunks() + subchunks))
    }

    /// The setup save's frames without what that save itself added: a `TXXX` whose description
    /// the base fixture's tag lacks (other than the app's custom tag), and exact duplicates.
    /// Otherwise the before-state already carries the effect a cell looks for.
    private static func framesAsAnotherAppWroteThem(_ frames: [ID3v2Frames.Frame]) throws -> [ID3v2Frames.Frame] {
        let base = try RIFFChunks(contentsOf: TestBundleResources.shared.tabla_wav)
        let baseTag = try base.first("ID3 ").flatMap { try ID3v2Frames.tag(in: $0.payload) }
        let baseDescriptions = try Set((baseTag?.frames("TXXX") ?? []).map { try ID3v2Frames.UserText($0.body).description })

        var seen: [ID3v2Frames.Frame] = []

        for frame in frames where !seen.contains(frame) {
            if frame.id == "TXXX" {
                let description = try ID3v2Frames.UserText(frame.body).description
                guard description == SafetyNetSetup.customTagKey || baseDescriptions.contains(description) else { continue }
            }
            seen.append(frame)
        }

        return seen
    }
}
