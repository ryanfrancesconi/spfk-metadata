// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
import Testing

@testable import SPFKMetadata

/// A test argument: one save kind on one row.
struct SafetyNetCase: Sendable, CustomTestStringConvertible {
    let row: SafetyNetRow
    let kind: SaveKind

    var testDescription: String { "\(row.name) \(kind.rawValue)" }

    /// Every applicable pairing, row-major.
    static func cases(rows: [SafetyNetRow], kinds: [SaveKind]) -> [SafetyNetCase] {
        rows.flatMap { row in
            kinds.filter { $0.applies(to: row) }.map { SafetyNetCase(row: row, kind: $0) }
        }
    }
}

extension SafetyNetComponent {
    /// The items an independent reader exposes for this component.
    var items: [SafetyNetItem] {
        switch self {
        case .finderTags: [.finderTags]
        default: []
        }
    }

    /// What the component's items read after ``SafetyNetEdit`` was saved.
    var editedValues: [SafetyNetItem: SafetyNetValue] {
        switch self {
        case .finderTags: [.finderTags: .text([SafetyNetEdit.finderTag])]
        default: [:]
        }
    }
}

/// Runs one cell: prepare the fixture, snapshot, save, snapshot, compare item by item.
enum SafetyNetCell {
    static func run(_ testCase: SafetyNetCase, in bin: URL) async throws {
        let row = testCase.row
        let kind = testCase.kind
        let url = try await row.prepare(in: bin)

        let writtenItems = Set(kind.written.flatMap(\.items))
        var items = row.components.sorted { $0.rawValue < $1.rawValue }.flatMap(\.items) + row.foreignItems.map(\.item)

        if !kind.writesContainer {
            items.insert(.wholeFile, at: 0)
        }

        let before = try SafetyNetSnapshot(of: url, items: items)
        try before.requirePresent(items, row: row)

        var description = try await MetaAudioFileDescription(parsing: url)
        try kind.run(on: &description, row: row)

        let after = try SafetyNetSnapshot(of: url, items: items)

        for item in items where !writtenItems.contains(item) {
            SafetyNetSnapshot.expectUnchanged(item, before: before, after: after, row: row, kind: kind)
        }

        for component in kind.written {
            for (item, value) in component.editedValues {
                SafetyNetSnapshot.expectWritten(item, value, after: after, row: row, kind: kind)
            }
        }

        try await expectOurReaderAgrees(kind: kind, row: row, url: url)
    }

    /// Our own reader, asserted beside the independent one and never instead of it.
    private static func expectOurReaderAgrees(kind: SaveKind, row: SafetyNetRow, url: URL) async throws {
        #if os(macOS)
            if kind.written.contains(.finderTags) {
                // A fresh URL: the original's resource values are cached.
                let reread = try await MetaAudioFileDescription(parsing: URL(fileURLWithPath: url.path))
                let labels = reread.urlProperties.finderTags.tags.map(\.label)
                #expect(labels == [SafetyNetEdit.finderTag], "\(row.name) \(kind.rawValue) our reader's Finder tags")
            }
        #endif
    }
}
