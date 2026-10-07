// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CryptoKit
import Foundation
import SPFKTesting

/// One thing in a FLAC's metadata blocks. Vorbis field names compare case-insensitively.
enum SafetyNetFLACItem: String, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    // Owned
    case title, customTag, otherFields, rating, frontCover, frontCoverPixels, chapters
    case bextDescription, bextDateTime, bextOther, iXML

    // Foreign
    case unknownField, multiValuedField, lowerCaseField, vendor, otherPictures, cueSheet, seekTable
    case otherApplication, foreignRIFF

    // Layout
    case blockSet

    var description: String {
        switch self {
        case .title: "TITLE"
        case .customTag: SafetyNetSetup.customTagKey
        case .otherFields: "other Vorbis fields"
        case .rating: "RATING + FMPS_RATING"
        case .frontCover: "PICTURE(front cover)"
        case .frontCoverPixels: "PICTURE(front cover) pixel size"
        case .chapters: "CHAPTERnnn fields"
        case .bextDescription: "riff/bext Description"
        case .bextDateTime: "riff/bext OriginationDate and OriginationTime"
        case .bextOther: "riff/bext after Description, date and time aside"
        case .iXML: "riff/iXML tree"
        case .unknownField: SafetyNetFLACForeign.unknownFieldKey
        case .multiValuedField: SafetyNetFLACForeign.multiValuedFieldKey
        case .lowerCaseField: SafetyNetFLACForeign.lowerCaseFieldKey
        case .vendor: "vendor string"
        case .otherPictures: "PICTURE(other)"
        case .cueSheet: "CUESHEET"
        case .seekTable: "SEEKTABLE"
        case .otherApplication: "APPLICATION \(SafetyNetFLACForeign.applicationID)"
        case .foreignRIFF: "riff-wrapped foreign chunks, in order"
        case .blockSet: "block set"
        }
    }

    static let ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [
        .tags: [.flac(.title), .flac(.customTag), .flac(.otherFields)],
        .rating: [.flac(.rating)],
        .artwork: [.flac(.frontCover), .flac(.frontCoverPixels)],
        .markers: [.flac(.chapters)],
        .bext: [.flac(.bextDescription), .flac(.bextDateTime), .flac(.bextOther)],
        .iXML: [.flac(.iXML)],
    ]

    /// Other applications' fields and blocks, planted by ``SafetyNetFLACPlant``.
    static let foreignItems: [SafetyNetForeignItem] = [
        .unknownField, .multiValuedField, .lowerCaseField, .vendor, .otherPictures, .cueSheet, .seekTable,
        .otherApplication, .foreignRIFF,
    ].map { SafetyNetForeignItem(item: .flac($0)) }
}

// MARK: - Reading

extension SafetyNetFLACItem {
    /// Fields another item reads. `METADATA_BLOCK_PICTURE` is artwork, which the fixtures store
    /// as `PICTURE` blocks.
    private static let fieldsReadElsewhere: Set<String> = [
        "TITLE", SafetyNetSetup.customTagKey, "RATING", "FMPS_RATING", "METADATA_BLOCK_PICTURE",
        SafetyNetFLACForeign.unknownFieldKey, SafetyNetFLACForeign.multiValuedFieldKey, SafetyNetFLACForeign.lowerCaseFieldKey.uppercased(),
    ]

    func read(from flac: FLACBlocks?) throws -> SafetyNetValue? {
        guard let flac else { return nil }

        func text(_ lines: [String]) -> SafetyNetValue? {
            lines.isEmpty ? nil : .text(lines)
        }

        func bytes(_ blocks: [FLACBlocks.Block]) -> SafetyNetValue? {
            blocks.isEmpty ? nil : .bytes(blocks.map(\.payload).reduce(Data(), +))
        }

        let comment = try flac.vorbisComment()
        let fields = comment?.fields ?? []

        func values(_ key: String) -> SafetyNetValue? {
            text(comment?.values(key) ?? [])
        }

        switch self {
        case .title:
            return values("TITLE")

        case .customTag:
            return values(SafetyNetSetup.customTagKey)

        case .unknownField:
            return values(SafetyNetFLACForeign.unknownFieldKey)

        case .multiValuedField:
            return values(SafetyNetFLACForeign.multiValuedFieldKey)

        case .lowerCaseField:
            return values(SafetyNetFLACForeign.lowerCaseFieldKey)

        case .rating:
            return text(fields.filter { ["RATING", "FMPS_RATING"].contains($0.key.uppercased()) }.map { "\($0.key.uppercased())=\($0.value)" }.sorted())

        case .otherFields:
            let others = fields.filter { !Self.fieldsReadElsewhere.contains($0.key.uppercased()) && !$0.key.uppercased().hasPrefix("CHAPTER") }
            return text(others.map { "\($0.key.uppercased())=\($0.value)" }.sorted())

        case .vendor:
            return comment.map { .text([$0.vendor]) }

        case .chapters:
            return try text(Self.chapterLines(fields))

        case .frontCover:
            return try text(flac.pictures().filter { $0.pictureType == 3 }.map(Self.line))

        case .otherPictures:
            return try text(flac.pictures().filter { $0.pictureType != 3 }.map(Self.line).sorted())

        case .frontCoverPixels:
            return try text(flac.pictures().filter { $0.pictureType == 3 }.map { picture in
                do { return try SafetyNetImage.pixelSize(of: picture.data) } catch { return "undecodable \(picture.mimeType)" }
            })

        case .cueSheet:
            return bytes(flac.blocks(.cueSheet))

        case .seekTable:
            return bytes(flac.blocks(.seekTable))

        case .otherApplication:
            return bytes(flac.blocks(.application).filter { $0.applicationID == SafetyNetFLACForeign.applicationID })

        case .foreignRIFF:
            let chunks = try flac.blocks(.application).compactMap { block in
                try block.riffChunk().map { (chunk: $0, block: block) }
            }.filter { !Self.ownedChunkIDs.contains($0.chunk.id) }

            return text(chunks.map { "\($0.chunk.id) \($0.block.payload.count) bytes, sha256 \(Self.digest($0.block.payload))…" })

        case .bextDescription:
            return try Self.ownedChunk("bext", in: flac).map { try .text([RIFFChunks.BroadcastExtension($0).description]) }

        case .bextDateTime:
            return try Self.ownedChunk("bext", in: flac).map { .bytes(Data($0.dropFirst(320).prefix(18))) }

        case .bextOther:
            return try Self.ownedChunk("bext", in: flac).map { .bytes(Data($0.dropFirst(256).prefix(64)) + Data($0.dropFirst(338))) }

        case .iXML:
            return try Self.ownedChunk("iXML", in: flac).map { try .text(XMLTree($0).lines) }

        case .blockSet:
            return try .text(flac.blocks.filter { $0.blockType != .padding }.map(Self.blockLine).sorted())
        }
    }

    /// The chunks the app writes into `APPLICATION` blocks.
    static let ownedChunkIDs: Set<String> = ["iXML", "bext"]

    /// An owned chunk's payload, wrapped in `riff` or stored directly under its own ID.
    private static func ownedChunk(_ id: String, in flac: FLACBlocks) throws -> Data? {
        for block in flac.blocks(.application) {
            if let chunk = try block.riffChunk(), chunk.id == id { return chunk.payload }
            if block.applicationID == id { return Data(block.payload.dropFirst(4)) }
        }
        return nil
    }

    /// `CHAPTERnnn` fields as `start "name"` lines, plus `–end` where an `END` field is stored, in
    /// chapter-number order.
    static func chapterLines(_ fields: [VorbisComment.Field]) throws -> [String] {
        var byNumber: [Int: [String: String]] = [:]

        for field in fields {
            let key = field.key.uppercased()
            guard key.hasPrefix("CHAPTER"), key.count >= 10, let number = Int(key.dropFirst(7).prefix(3)) else { continue }
            byNumber[number, default: [:]][String(key.dropFirst(10))] = field.value
        }

        return byNumber.keys.sorted().compactMap { number in
            let parts = byNumber[number] ?? [:]
            guard let start = parts[""] else { return nil }
            return chapterLine(start: start, end: parts["END"], name: parts["NAME"])
        }
    }

    static func chapterLine(start: String, end: String?, name: String?) -> String {
        "\(start)\(end.map { "–\($0)" } ?? "") \(name.map { "\"\($0)\"" } ?? "unnamed")"
    }

    /// `HH:MM:SS.mmm`, the form Xiph chapter fields store.
    static func timestamp(_ seconds: TimeInterval) -> String {
        let milliseconds = Int((seconds * 1000).rounded())
        return String(format: "%02d:%02d:%02d.%03d", milliseconds / 3_600_000, milliseconds / 60000 % 60, milliseconds / 1000 % 60, milliseconds % 1000)
    }

    static func line(_ picture: FLACBlocks.Picture) -> String {
        "type \(picture.pictureType), \(picture.mimeType), \"\(picture.description)\", sha256 \(digest(picture.data))…"
    }

    private static func blockLine(_ block: FLACBlocks.Block) throws -> String {
        if let chunk = try block.riffChunk() { return "APPLICATION riff/\(chunk.id)" }
        if let id = block.applicationID { return "APPLICATION \(id)" }

        switch block.blockType {
        case .streamInfo: return "STREAMINFO"
        case .seekTable: return "SEEKTABLE"
        case .vorbisComment: return "VORBIS_COMMENT"
        case .cueSheet: return "CUESHEET"
        case .picture: return "PICTURE"
        default: return "type \(block.type)"
        }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Expectations

extension SafetyNetFLACItem {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        switch self {
        case .title:
            return .value(.text([SafetyNetEdit.title]))

        case .customTag:
            return .value(.text([SafetyNetEdit.customTagValue]))

        case .rating:
            return .value(.text(SafetyNetFLACForeign.ratingFields))

        case .frontCover:
            return kind == .k6 ? .value(nil) : .unpredictable

        case .frontCoverPixels:
            return kind == .k6 ? .value(nil) : try .value(.text([SafetyNetEdit.artworkPixelSize()]))

        case .chapters:
            guard kind != .k8 else { return .value(nil) }
            return .value(.text(SafetyNetEdit.markers.map { marker in
                let end = marker.endTime.flatMap { $0 > marker.startTime ? Self.timestamp($0) : nil }
                return Self.chapterLine(start: Self.timestamp(marker.startTime), end: end, name: marker.name)
            }))

        case .bextDescription:
            return .value(.text([SafetyNetEdit.bextSequenceDescription]))

        case .iXML:
            let edited = SafetyNetRIFFForeign.iXML.replacingOccurrences(of: SafetyNetSetup.iXMLProject, with: SafetyNetEdit.iXMLProject)
            return try .value(.text(XMLTree(edited).lines))

        default:
            return .unchanged
        }
    }
}
