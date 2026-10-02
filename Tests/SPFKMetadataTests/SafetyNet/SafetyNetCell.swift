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
    /// The items an independent reader exposes for this component on every row; a row adds its
    /// container's own through ``SafetyNetRow/ownedItems``.
    var items: [SafetyNetItem] {
        switch self {
        case .finderTags: [.finderTags]
        default: []
        }
    }
}

/// What a save kind that writes an item's component leaves in it.
enum SafetyNetWrite {
    /// As before the save: an item the component holds but the kind does not edit.
    case unchanged
    /// What the independent reader must show; nil when the item must be gone.
    case value(SafetyNetValue?)
    /// Rewritten to bytes no test can predict, such as a re-encoded image; another item checks it.
    case unpredictable
}

extension SafetyNetItem {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        switch self {
        case .finderTags: .value(.text([SafetyNetEdit.finderTag]))
        case .wholeFile, .xattr: .unchanged
        case let .id3(item): try item.written(by: kind, after: after)
        }
    }
}

/// Runs one cell: prepare the fixture, snapshot, save, snapshot, compare item by item.
enum SafetyNetCell {
    static func run(_ testCase: SafetyNetCase, in bin: URL) async throws {
        let row = testCase.row
        let kind = testCase.kind
        let url = try await row.prepare(in: bin)

        var items = row.components.sorted { $0.rawValue < $1.rawValue }.flatMap(row.items(for:)) + row.foreignItems.map(\.item)

        if !kind.writesContainer {
            items.insert(.wholeFile, at: 0)
        }

        let before = try SafetyNetSnapshot(of: url, items: items)
        try before.requirePresent(items, row: row)

        var description = try await MetaAudioFileDescription(parsing: url)
        try kind.run(on: &description, row: row)

        let after = try SafetyNetSnapshot(of: url, items: items)

        for item in items where SafetyNetCoveredCells.coveringTest(row: row, kind: kind, item: item) == nil {
            let isWritten = row.component(of: item).map(kind.written.contains) ?? false

            switch isWritten ? try item.written(by: kind, after: after) : .unchanged {
            case .unchanged:
                SafetyNetSnapshot.expectUnchanged(item, before: before, after: after, row: row, kind: kind)
            case let .value(value):
                SafetyNetSnapshot.expectWritten(item, value, after: after, row: row, kind: kind)
            case .unpredictable:
                break
            }
        }

        try await expectOurReaderAgrees(kind: kind, row: row, url: url)
    }

    /// Our own reader, asserted beside the independent one and never instead of it.
    private static func expectOurReaderAgrees(kind: SaveKind, row: SafetyNetRow, url: URL) async throws {
        let written = kind.written.intersection(row.components)
        guard !written.isEmpty else { return }

        // A fresh URL: the original's resource values are cached.
        let reread = try await MetaAudioFileDescription(parsing: URL(fileURLWithPath: url.path))
        let context = "\(row.name) \(kind.rawValue) our reader's"

        if written.contains(.tags) {
            #expect(reread.tagProperties[.title] == SafetyNetEdit.title, "\(context) title")
            #expect(reread.tagProperties.data.customTag(for: SafetyNetSetup.customTagKey) == SafetyNetEdit.customTagValue, "\(context) custom tag")
        }

        if written.contains(.rating) {
            #expect(reread.tagProperties[.rating] == SafetyNetEdit.rating, "\(context) rating")
        }

        if written.contains(.artwork) {
            let size = reread.imageDescription.cgImage.map { "\($0.width)x\($0.height)" }
            #expect(size == (kind == .k6 ? nil : try SafetyNetEdit.artworkPixelSize()), "\(context) artwork")
        }

        if written.contains(.markers) {
            #expect(reread.markerCollection.markerDescriptions.map(\.name) == SafetyNetEdit.markers.map(\.name), "\(context) markers")
        }

        if written.contains(.packet) {
            let expected = kind == .k17 ? nil : SafetyNetEdit.packet
            #expect(StoredXMPPacketWrite.storedPacket(in: url) == expected, "\(context) packet")
        }

        #if os(macOS)
            if written.contains(.finderTags) {
                let labels = reread.urlProperties.finderTags.tags.map(\.label)
                #expect(labels == [SafetyNetEdit.finderTag], "\(context) Finder tags")
            }
        #endif
    }
}
