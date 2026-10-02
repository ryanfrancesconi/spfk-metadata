// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CryptoKit
import Foundation
import SPFKTesting
import Testing

/// One thing a cell checks: an owned component's on-disk form, a foreign datum, or the file.
enum SafetyNetItem: Hashable, Sendable, CustomStringConvertible {
    /// Every byte of the file.
    case wholeFile
    /// Finder's tag attribute, decoded to its stored strings.
    case finderTags
    /// One extended attribute's bytes.
    case xattr(name: String)
    /// Something in a leading ID3v2 tag.
    case id3(SafetyNetID3Item)

    var description: String {
        switch self {
        case .wholeFile: "whole file"
        case .finderTags: "Finder tags"
        case let .xattr(name): "xattr \(name)"
        case let .id3(item): "ID3 \(item)"
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

    /// The leading ID3v2 tag, when an item asked for it.
    private(set) var id3Tag: ID3v2Frames.Tag?

    init(of url: URL, items: [SafetyNetItem]) throws {
        let data = try Data(contentsOf: url)

        if items.contains(where: { if case .id3 = $0 { true } else { false } }) {
            id3Tag = try ID3v2Frames.tag(in: data)
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

        case .finderTags:
            try FileXattrs.userTags(of: url).map(SafetyNetValue.text)

        case let .xattr(name):
            try FileXattrs.value(name, of: url).map(SafetyNetValue.bytes)

        case let .id3(id3Item):
            try id3Item.read(from: id3Tag, file: data, url: url)
        }
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
