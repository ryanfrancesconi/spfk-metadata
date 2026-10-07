// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting
import Testing

/// One thing in a WAV's RIFF chunks outside its `ID3 ` chunk, which ``SafetyNetID3Item`` reads.
enum SafetyNetRIFFItem: Hashable, Sendable, CustomStringConvertible {
    // Owned
    case infoTitle, infoRating, infoComment, otherInfo, markers, bextDescription, bextDateTime, bextOther, iXML, xmpPacket

    // Foreign
    case unknownInfo, otherAssociatedData
    /// Where the `data` chunk starts. A save that moves it has rewritten the whole audio in place.
    case dataOffset
    /// An RF64 file's long-form header: the magic, the sentinel in both 32-bit sizes, and `ds64`
    /// sizes that match the file. A real size where a sentinel belongs makes other readers ignore
    /// `ds64` and believe it.
    case longForm
    /// A whole top-level chunk no writer of ours knows, compared byte for byte.
    case chunk(String)

    var description: String {
        switch self {
        case .infoTitle: "INFO INAM"
        case .infoRating: "INFO IRTD"
        case .infoComment: "INFO ICMT"
        case .otherInfo: "other INFO items"
        case .markers: "cue + adtl labl"
        case .bextDescription: "bext Description"
        case .bextDateTime: "bext OriginationDate and OriginationTime"
        case .bextOther: "bext after Description, date and time aside"
        case .iXML: "iXML tree"
        case .xmpPacket: "_PMX"
        case .unknownInfo: "INFO \(SafetyNetRIFFForeign.unknownInfoID)"
        case .otherAssociatedData: "adtl note/ltxt"
        case .dataOffset: "data chunk offset"
        case .longForm: "long-form header"
        case let .chunk(id): "chunk \(id)"
        }
    }

    /// The WAV row's owned items: the `ID3 ` chunk's and the RIFF chunks' that mirror or hold
    /// each component.
    static let ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [
        .tags: [
            .id3(.title), .id3(.customTag), .id3(.otherText), .id3(.frameIDUserText), .id3(.duplicateUserText), .id3(.infoUserText),
            .riff(.infoTitle), .riff(.infoComment), .riff(.otherInfo),
        ],
        .rating: [.id3(.rating), .riff(.infoRating)],
        .artwork: [.id3(.frontCover), .id3(.frontCoverPixels), .id3(.frontCoverPath)],
        .markers: [.riff(.markers)],
        .bext: [.riff(.bextDescription), .riff(.bextDateTime), .riff(.bextOther)],
        .iXML: [.riff(.iXML)],
        .packet: [.riff(.xmpPacket)],
    ]

    /// Other applications' ID3 frames and RIFF data, planted by ``SafetyNetRIFFPlant``.
    static let foreignItems: [SafetyNetForeignItem] =
        SafetyNetID3Item.foreignFrames.map { SafetyNetForeignItem(item: .id3($0)) }
            + ([.unknownInfo] + SafetyNetRIFFForeign.unknownChunkIDs.map(SafetyNetRIFFItem.chunk) + [.otherAssociatedData, .dataOffset])
            .map { SafetyNetForeignItem(item: .riff($0)) }
}

// MARK: - Reading

extension SafetyNetRIFFItem {
    /// INFO IDs another item reads. `IART` mirrors `TPE1`, which the plant gives two values
    /// where INFO holds one, so it is not compared.
    private static let infoReadElsewhere: Set<String> = ["INAM", "IRTD", "ICMT", "IART", SafetyNetRIFFForeign.unknownInfoID]

    func read(from riff: RIFFChunks?, file: Data) throws -> SafetyNetValue? {
        guard let riff else { return nil }

        func text(_ lines: [String]) -> SafetyNetValue? {
            lines.isEmpty ? nil : .text(lines)
        }

        func info(_ id: String) throws -> SafetyNetValue? {
            try text(riff.infoItems().filter { $0.id == id }.map(\.value))
        }

        switch self {
        case .infoTitle:
            return try info("INAM")

        case .infoRating:
            return try info("IRTD")

        case .infoComment:
            return try info("ICMT")

        case .unknownInfo:
            return try info(SafetyNetRIFFForeign.unknownInfoID)

        case .otherInfo:
            return try text(riff.infoItems().filter { !Self.infoReadElsewhere.contains($0.id) }.map { "\($0.id): \($0.value)" }.sorted())

        case .markers:
            let labels = try riff.labels()
            return try text(riff.cuePoints().sorted { $0.sampleOffset < $1.sampleOffset }.map {
                Self.markerLine(frame: $0.sampleOffset, name: labels[$0.id])
            })

        case .dataOffset:
            return Self.dataOffset(in: riff).map { .text(["\($0)"]) }

        case .longForm:
            return Self.longFormHeader(of: riff, file: file)

        case .otherAssociatedData:
            let chunks = try riff.associatedData().filter { $0.id != "labl" }
            return chunks.isEmpty ? nil : .bytes(RIFFChunkBuilder.encode(chunks))

        case .bextDescription:
            return try riff.broadcastExtension().map { .text([$0.description]) }

        case .bextDateTime:
            return riff.first("bext").map { .bytes(Data($0.payload.dropFirst(320).prefix(18))) }

        case .bextOther:
            return riff.first("bext").map { .bytes(Data($0.payload.dropFirst(256).prefix(64)) + Data($0.payload.dropFirst(338))) }

        case .iXML:
            return try riff.first("iXML").map { try .text(XMLTree($0.payload).lines) }

        case .xmpPacket:
            return riff.first("_PMX").map { .bytes($0.payload) }

        case let .chunk(id):
            return riff.first(id).map { .bytes($0.payload) }
        }
    }

    private static func dataOffset(in riff: RIFFChunks) -> Int? {
        guard let index = riff.chunks.firstIndex(where: { $0.id == "data" }) else { return nil }
        return riff.chunks[..<index].reduce(12) { $0 + 8 + $1.payload.count + $1.payload.count % 2 }
    }

    /// Each fact as a line that reads the same before and after any save that keeps the form, so
    /// sizes are stated as matching or not rather than as numbers.
    private static func longFormHeader(of riff: RIFFChunks, file: Data) -> SafetyNetValue {
        func storedSize(at offset: Int) -> String {
            let value = file.dropFirst(offset).prefix(4).reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            return value == RIFFChunks.longFormSizeSentinel ? "sentinel" : String(format: "0x%08x", value)
        }

        var lines = ["magic \(riff.form)", "size field \(storedSize(at: 4))", "first chunk \(riff.chunks.first?.id ?? "none")"]

        if let offset = dataOffset(in: riff) {
            lines.append("data size field \(storedSize(at: offset + 4))")
        }

        if let sizes = riff.longFormSizes {
            let dataSize = riff.first("data")?.payload.count ?? 0
            lines.append(sizes.riffSize == UInt64(file.count - 8) ? "ds64 riffSize matches" : "ds64 riffSize \(sizes.riffSize), file \(file.count - 8)")
            lines.append(sizes.dataSize == UInt64(dataSize) ? "ds64 dataSize matches" : "ds64 dataSize \(sizes.dataSize), data \(dataSize)")
        }

        return .text(lines)
    }

    static func markerLine(frame: UInt32, name: String?) -> String {
        "frame \(frame) \(name.map { "\"\($0)\"" } ?? "unlabeled")"
    }
}

// MARK: - Expectations

extension SafetyNetRIFFItem {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        switch self {
        case .infoTitle:
            return .value(.text([SafetyNetEdit.title]))

        case .infoRating:
            return .value(.text([SafetyNetEdit.rating]))

        case .markers:
            guard kind != .k8 else { return .value(nil) }
            let sampleRate = try Double(#require(after.riff?.sampleRate))
            return .value(.text(SafetyNetEdit.markers.map {
                Self.markerLine(frame: UInt32(($0.startTime * sampleRate).rounded()), name: $0.name)
            }))

        case .bextDescription:
            return .value(.text([SafetyNetEdit.bextSequenceDescription]))

        case .iXML:
            let edited = SafetyNetRIFFForeign.iXML.replacingOccurrences(of: SafetyNetSetup.iXMLProject, with: SafetyNetEdit.iXMLProject)
            return try .value(.text(XMLTree(edited).lines))

        case .xmpPacket:
            return .value(kind == .k17 ? nil : .bytes(Data(SafetyNetEdit.packet.utf8)))

        default:
            return .unchanged
        }
    }
}
