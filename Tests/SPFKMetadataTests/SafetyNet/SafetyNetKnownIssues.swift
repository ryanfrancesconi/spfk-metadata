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
    static let table: [SafetyNetKnownIssue] = id3 + wave + aiff + flac + ogg + mp4 + matroska + entryPoints + combined

    /// Every MP3 save that writes the container; AAC's are the subset without markers or a packet.
    private static let mp3ContainerKinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .s1, .s2, .k15, .k16, .k17]
    /// Every MP3 save that writes the tag; a packet-only save (K15, K17) rewrites only the `PRIV`.
    private static let mp3TagKinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .s1, .s2, .k16]

    private static let id3: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["mp3", "aac"], kinds: mp3TagKinds, item: .id3(.artist),
            text: "An MP3 tag save flattens a multi-valued TPE1: expected two values, found one joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3", "aac"], kinds: mp3TagKinds, item: .id3(.userText),
            text: "An MP3 tag save upper-cases other apps' TXXX descriptions: expected \"SafetyNet Foreign\", found \"SAFETYNET FOREIGN\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3", "aac"], kinds: mp3TagKinds, item: .id3(.lyrics),
            text: "An MP3 tag save rewrites other apps' USLT frames: expected language \"eng\" and description \"Safety Net\", found \"XXX\" and \"SAFETY NET\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3", "aac"], kinds: mp3TagKinds, item: .id3(.userURL),
            text: "An MP3 tag save upper-cases other apps' WXXX descriptions: expected \"Safety Net Link\", found \"SAFETY NET LINK\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3", "aac"], kinds: mp3TagKinds, item: .id3(.comments),
            text: "An MP3 tag save merges a second-language COMM into the first and rewrites a described one: expected 3 frames with languages \"eng\" and \"fra\" kept, found 2, one joined with a space and one \"XXX | SAFETY NET NOTE\" (F15, F29)"
        ),
    ]

    /// Every WAV and RF64 save that writes tags: all but the packet-only saves, which rewrite only `_PMX`.
    private static let wavTagKinds: Set<SaveKind> = [.k0, .k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .s1, .s2, .k16]

    private static let wave: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .id3(.artist),
            text: "A WAV tag save flattens a multi-valued TPE1: expected two values, found one joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .id3(.lyrics),
            text: "A WAV tag save moves another app's USLT into a TXXX: expected the USLT frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .id3(.userURL),
            text: "A WAV tag save moves another app's WXXX into a TXXX: expected the WXXX frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .id3(.involvedPeople),
            text: "A WAV tag save moves another app's TIPL into a TXXX: expected the TIPL frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .id3(.frameIDUserText),
            text: "A WAV tag save writes USLT, WXXX and TIPL as TXXX frames named after them: expected none, found three (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .id3(.comments),
            text: "A WAV tag save drops a second undescribed COMM in another language: expected the \"fra\" frame kept beside the file's comment, found it removed (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .id3(.duplicateUserText),
            text: "A WAV tag save adds a second TXXX with a description already present: expected each description once, found one twice (F33)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds.subtracting([.k1, .k16, .s1, .s2]), item: .id3(.infoUserText),
            text: "A WAV save that edits no tag still rewrites the tags, adding an INFO item to ID3: expected no new TXXX, found TXXX NUMCOLORS (F47)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .riff(.unknownInfo),
            text: "A WAV tag save drops INFO items it has no key for: expected IFRM, found none (F20)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: wavTagKinds, item: .riff(.iXML),
            text: "A WAV tag save re-serializes iXML, dropping comments and turning CDATA into escaped text: expected the comment and CDATA nodes, found neither (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav", "rf64"], kinds: [.k0, .k7, .k8, .s1], item: .riff(.otherAssociatedData),
            text: "A WAV marker save drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
    ]

    /// Every AIFF save kind in the net: each runs the tag save first.
    private static let aiffKinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .k8, .s1, .s2]

    private static let aiff: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["aiff", "aifc"], kinds: aiffKinds, item: .id3(.artist),
            text: "An AIFF save flattens a multi-valued TPE1: expected two values, found one joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["aiff", "aifc"], kinds: aiffKinds, item: .id3(.userText),
            text: "An AIFF save upper-cases other apps' TXXX descriptions: expected \"SafetyNet Foreign\", found \"SAFETYNET FOREIGN\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["aiff", "aifc"], kinds: aiffKinds, item: .id3(.lyrics),
            text: "An AIFF save rewrites other apps' USLT frames: expected language \"eng\" and description \"Safety Net\", found \"XXX\" and \"SAFETY NET\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["aiff", "aifc"], kinds: aiffKinds, item: .id3(.userURL),
            text: "An AIFF save upper-cases other apps' WXXX descriptions: expected \"Safety Net Link\", found \"SAFETY NET LINK\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["aiff", "aifc"], kinds: aiffKinds, item: .id3(.comments),
            text: "An AIFF save merges a second-language COMM into the first and rewrites a described one: expected the \"eng\" and \"fra\" frames kept, found them merged and upper-cased (F15, F29)"
        ),
    ]

    /// Every FLAC save that writes the container: each runs the iXML/BEXT write and the tag save.
    private static let flacContainerKinds: Set<SaveKind> = [.k0, .k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .s1, .s2]

    private static let flac: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: flacContainerKinds, item: .flac(.multiValuedField),
            text: "A FLAC save flattens a repeated Vorbis field: expected ENCODER twice, found one value joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: flacContainerKinds.subtracting([.k4]), item: .flac(.iXML),
            text: "A FLAC save re-serializes iXML, dropping comments and turning CDATA into escaped text: expected the comment and CDATA nodes, found neither (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: [.k4], item: .flac(.iXML),
            text: "A FLAC iXML edit re-serializes the rest of the document, dropping comments and turning CDATA into escaped text: expected the edit beside the comment and CDATA nodes, found neither (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac-ixml-only-bext"], kinds: [.k1, .k2, .k5], item: .flac(.blockSet),
            text: "A FLAC save writes a bext block for a BEXT held only in iXML's <BEXT>: expected no bext block, found one (F39)"
        ),
    ]

    /// Every Ogg Vorbis and Opus save kind in the net: each runs the tag save first.
    private static let oggKinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .k8, .s1, .s2]

    private static let ogg: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["ogg", "opus"], kinds: oggKinds, item: .ogg(.multiValuedField),
            text: "An Ogg save flattens a repeated comment field: expected ENCODER twice, found one value joined with a space (F15)"
        ),
    ]

    /// Every MP4-family save kind in the net: each runs the tag save first.
    private static let mp4Kinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .k8, .s1, .s2]

    private static let mp4: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b", "mp4", "m4v", "mov"], kinds: mp4Kinds, item: .mp4(.multiValuedText),
            text: "An MP4 save flattens a multi-valued text item: expected ©ART twice, found one value joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b", "mp4", "m4v", "mov"], kinds: [.k7, .s1], item: .mp4(.chapters),
            text: "An MP4 marker save whose first marker starts after zero adds an untitled chapter at zero that other players list: expected the written chapters only, found an extra one at 0.000 (F41)"
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
