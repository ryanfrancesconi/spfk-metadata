// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import CryptoKit
import Foundation
import SPFKTesting
import Testing

/// One thing a cell checks: an owned component's on-disk form, a foreign datum, or the file.
enum SafetyNetItem: Hashable, Sendable, CustomStringConvertible {
    /// Every byte of the file.
    case wholeFile
    /// The coded audio, as ``SafetyNetSnapshot/audioPayload(of:)`` extracts it. No save may change it.
    case audio
    /// Finder's tag attribute, decoded to its stored strings.
    case finderTags
    /// One extended attribute's bytes.
    case xattr(name: String)
    /// Something in an ID3v2 tag: a leading one, or a WAV's `ID3 ` chunk.
    case id3(SafetyNetID3Item)
    /// Something in a WAV's RIFF chunks.
    case riff(SafetyNetRIFFItem)
    /// Something in an AIFF's chunks.
    case aiff(SafetyNetAIFFItem)
    /// Something in an Ogg Vorbis or Opus file's comment header.
    case ogg(SafetyNetOggItem)
    /// Something in a FLAC's metadata blocks.
    case flac(SafetyNetFLACItem)
    /// Something in an MP4's atoms, or its chapters as AVFoundation reads them.
    case mp4(SafetyNetMP4Item)
    /// What our own reader shows for a component after the save; checked beside the independent
    /// readers, never read into a snapshot.
    case ourReader(SafetyNetComponent)

    var description: String {
        switch self {
        case .wholeFile: "whole file"
        case .audio: "audio payload"
        case .finderTags: "Finder tags"
        case let .xattr(name): "xattr \(name)"
        case let .id3(item): "ID3 \(item)"
        case let .riff(item): "RIFF \(item)"
        case let .aiff(item): "AIFF \(item)"
        case let .ogg(item): "Ogg \(item)"
        case let .flac(item): "FLAC \(item)"
        case let .mp4(item): "MP4 \(item)"
        case let .ourReader(component): "our reader's \(component.rawValue)"
        }
    }
}

/// An item's value as an independent reader sees it. Equality is the item kind's equivalence: a
/// text list compares decoded values in order, bytes compare exactly.
enum SafetyNetValue: Equatable, Sendable, CustomStringConvertible {
    case bytes(Data)
    case text([String])

    var description: String {
        switch self {
        case let .bytes(data):
            let digest = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
            return "\(data.count) bytes, sha256 \(digest)…"
        case let .text(values):
            return "\(values)"
        }
    }

    /// Where two values part, for a failure message: the first differing byte offset and the
    /// bytes around it.
    func difference(from other: SafetyNetValue) -> String? {
        guard case let .bytes(lhs) = self, case let .bytes(rhs) = other else { return nil }

        let common = min(lhs.count, rhs.count)
        let offset = (0 ..< common).first { lhs[lhs.startIndex + $0] != rhs[rhs.startIndex + $0] } ?? common
        let window = max(0, offset - 8) ..< offset + 24

        func hex(_ data: Data) -> String {
            let range = window.clamped(to: 0 ..< data.count)
            return data[data.startIndex + range.lowerBound ..< data.startIndex + range.upperBound]
                .map { String(format: "%02x", $0) }.joined(separator: " ")
        }

        return "first difference at byte \(offset); expected [\(hex(lhs))], got [\(hex(rhs))]"
    }
}

/// Every declared item of a file, read without `spfk-metadata`. An item the file lacks has no
/// entry.
struct SafetyNetSnapshot {
    private(set) var values: [SafetyNetItem: SafetyNetValue] = [:]

    /// The ID3v2 tag, when an item asked for it: a RIFF file's `ID3 ` chunk, else the leading tag.
    private(set) var id3Tag: ID3v2Frames.Tag?

    /// A RIFF file's chunks.
    private(set) var riff: RIFFChunks?

    /// An AIFF or AIFF-C file's chunks.
    private(set) var aiff: AIFFChunks?

    /// An Ogg file's pages and packets.
    private(set) var ogg: OggPackets?

    /// A FLAC file's metadata blocks.
    private(set) var flac: FLACBlocks?

    /// An MP4 file's atoms.
    private(set) var mp4: MP4Atoms?

    /// An MP4's chapters as AVFoundation lists them, when an item asked for them.
    private(set) var mp4Chapters: [String]?

    /// An MP4's duration in seconds as AVFoundation reads it, when its chapters were read.
    private(set) var mp4Duration: Double?

    /// An MP4's first audio track decoded to PCM by AVFoundation, when the audio was asked for.
    private(set) var mp4AudioPCM: Data?

    init(of url: URL, items: [SafetyNetItem]) async throws {
        let data = try Data(contentsOf: url)

        if ["RIFF", "RF64", "BW64"].contains(where: { data.starts(with: Data($0.utf8)) }) {
            riff = try RIFFChunks(data)
        } else if data.starts(with: Data("FORM".utf8)) {
            aiff = try AIFFChunks(data)
        } else if data.starts(with: Data("OggS".utf8)) {
            ogg = try OggPackets(data)
        } else if FLACBlocks.isFLAC(data) {
            flac = try FLACBlocks(data)
        } else if data.count >= 8, data.subdata(in: 4 ..< 8) == Data("ftyp".utf8) {
            mp4 = try MP4Atoms(data)
        }

        if mp4 != nil, items.contains(.audio) {
            mp4AudioPCM = try Self.decodedPCM(of: url)
        }

        if mp4 != nil, items.contains(.mp4(.chapters)) {
            (mp4Chapters, mp4Duration) = try await Self.chapters(of: url)
        }

        if items.contains(where: { if case .id3 = $0 { true } else { false } }) {
            if let chunks = riff?.chunks ?? aiff?.chunks {
                id3Tag = try chunks.first { $0.id == "ID3 " || $0.id == "id3 " }.flatMap { try ID3v2Frames.tag(in: $0.payload) }
            } else {
                id3Tag = try ID3v2Frames.tag(in: data)
            }
        }

        for item in items {
            values[item] = try read(item, from: url, data: data)
        }
    }

    subscript(item: SafetyNetItem) -> SafetyNetValue? {
        values[item]
    }

    /// A fixture lacking a declared item tests nothing, so it fails rather than passes.
    func requirePresent(_ items: [SafetyNetItem], row: SafetyNetRow, sourceLocation: SourceLocation = #_sourceLocation) throws {
        for item in items {
            try #require(values[item] != nil, "\(row.name) fixture: \(item) missing before the save", sourceLocation: sourceLocation)
        }
    }

    private func read(_ item: SafetyNetItem, from url: URL, data: Data) throws -> SafetyNetValue? {
        switch item {
        case .wholeFile:
            .bytes(data)

        case .audio:
            audioPayload(of: data).map(SafetyNetValue.bytes)

        case .finderTags:
            try FileXattrs.userTags(of: url).map(SafetyNetValue.text)

        case let .xattr(name):
            try FileXattrs.value(name, of: url).map(SafetyNetValue.bytes)

        case let .id3(id3Item):
            try id3Item.read(from: id3Tag, file: data, url: url)

        case let .riff(riffItem):
            try riffItem.read(from: riff, file: data)

        case let .aiff(aiffItem):
            try aiffItem.read(from: aiff)

        case let .ogg(oggItem):
            try oggItem.read(from: ogg)

        case let .flac(flacItem):
            try flacItem.read(from: flac)

        case let .mp4(mp4Item):
            try mp4Item.read(from: mp4, chapters: mp4Chapters)

        case .ourReader:
            nil
        }
    }
}

// MARK: - AVFoundation

extension SafetyNetSnapshot {
    /// The QuickTime chapter track through AVFoundation, which shares no code with TagLib.
    private static func chapters(of url: URL) async throws -> ([String], Double) {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        // Whatever the file declares: a request naming no declared language lists no groups.
        let languages = try await asset.load(.availableChapterLocales).map(\.identifier) + ["und"]
        let groups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: languages)
        var lines: [String] = []

        for group in groups {
            var titles: [String] = []
            for item in group.items {
                guard item.commonKey == .commonKeyTitle else { continue }
                titles.append(try await item.load(.stringValue) ?? "")
            }
            lines.append(SafetyNetMP4Item.chapterLine(start: group.timeRange.start.seconds, title: titles.joined(separator: " | ")))
        }

        return (lines, duration)
    }
}

// MARK: - Comparison

extension SafetyNetSnapshot {
    /// (b) and (c): the item is as it was before the save.
    static func expectUnchanged(
        _ item: SafetyNetItem, before: SafetyNetSnapshot, after: SafetyNetSnapshot,
        row: SafetyNetRow, kind: SaveKind, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let expected = before[item]
        let actual = after[item]
        let detail = expected.flatMap { lhs in actual.flatMap { lhs.difference(from: $0) } }

        SafetyNetKnownIssues.expect(
            actual == expected,
            "\(row.name) \(kind.rawValue) \(role(of: item, in: row)) \(item): expected \(describe(expected)), got \(describe(actual))"
                + (detail.map { "; \($0)" } ?? ""),
            row: row, kind: kind, item: item, sourceLocation: sourceLocation
        )
    }

    /// (a): the item holds what the save wrote.
    static func expectWritten(
        _ item: SafetyNetItem, _ expected: SafetyNetValue?, after: SafetyNetSnapshot,
        row: SafetyNetRow, kind: SaveKind, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = after[item]

        SafetyNetKnownIssues.expect(
            actual == expected,
            "\(row.name) \(kind.rawValue) written \(item): expected \(describe(expected)), got \(describe(actual))",
            row: row, kind: kind, item: item, sourceLocation: sourceLocation
        )
    }

    private static func role(of item: SafetyNetItem, in row: SafetyNetRow) -> String {
        row.foreignItems.contains { $0.item == item } ? "foreign" : "owned"
    }

    private static func describe(_ value: SafetyNetValue?) -> String {
        value.map(\.description) ?? "nothing"
    }
}
