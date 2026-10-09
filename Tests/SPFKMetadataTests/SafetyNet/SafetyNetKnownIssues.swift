// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import Testing

/// A safety-net cell that fails on current code, scoped to exactly the rows and kinds it fails
/// on. The text states the defect, then expected against actual, then the finding number.
struct SafetyNetKnownIssue: Sendable {
    let rows: Set<String>
    let kinds: Set<SaveKind>
    let item: SafetyNetItem
    let text: String
}

/// The one table of known failures. Only the expectation an entry matches is wrapped, so a cell
/// that starts passing records `knownIssueNotRecorded` and turns the suite red until its entry is
/// removed.
enum SafetyNetKnownIssues {
    static let table: [SafetyNetKnownIssue] = wave + flac + matroska + entryPoints + combined

    /// Every WAV and RF64 save that renders iXML: all but the packet-only saves, which rewrite only `_PMX`.
    private static let wavIXMLKinds: Set<SaveKind> = [.k0, .k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .s1, .s2, .k16]

    private static let wave: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavIXMLKinds, item: .riff(.iXML),
            text: "A WAV tag save re-serializes iXML, dropping comments and turning CDATA into escaped text: expected the comment and CDATA nodes, found neither (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: [.k0, .k7, .k8, .s1], item: .riff(.otherAssociatedData),
            text: "A WAV marker save drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
    ]

    /// Every FLAC save that writes the container: each runs the iXML/BEXT write and the tag save.
    private static let flacContainerKinds: Set<SaveKind> = [.k0, .k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .s1, .s2]

    private static let flac: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: flacContainerKinds.subtracting([.k4]), item: .flac(.iXML),
            text: "A FLAC save re-serializes iXML, dropping comments and turning CDATA into escaped text: expected the comment and CDATA nodes, found neither (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: [.k4], item: .flac(.iXML),
            text: "A FLAC iXML edit re-serializes the rest of the document, dropping comments and turning CDATA into escaped text: expected the edit beside the comment and CDATA nodes, found neither (F13)"
        ),
    ]

    /// Every Matroska save kind in the net: each runs the tag save first.
    private static let matroskaKinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .s2]

    private static let matroska: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["mka", "mkv", "webm"], kinds: matroskaKinds, item: .matroska(.unknownTag),
            text: "A Matroska save moves another app's untargeted tag from album to track level: expected no TargetTypeValue, found 30 (F50)"
        ),
    ]

    static func issue(row: SafetyNetRow, kind: SaveKind, item: SafetyNetItem) -> SafetyNetKnownIssue? {
        table.first { $0.rows.contains(row.name) && $0.kinds.contains(kind) && $0.item == item }
    }

    /// `#expect(condition)`, inside `withKnownIssue` when the table lists this cell.
    static func expect(
        _ condition: Bool, _ message: String,
        row: SafetyNetRow, kind: SaveKind, item: SafetyNetItem, sourceLocation: SourceLocation
    ) {
        guard let issue = issue(row: row, kind: kind, item: item) else {
            #expect(condition, Comment(rawValue: message), sourceLocation: sourceLocation)
            return
        }

        withKnownIssue(Comment(rawValue: issue.text), sourceLocation: sourceLocation) {
            #expect(condition, Comment(rawValue: message), sourceLocation: sourceLocation)
        }
    }
}
