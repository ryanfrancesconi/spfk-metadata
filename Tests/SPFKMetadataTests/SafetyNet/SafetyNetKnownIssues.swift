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
    static let table: [SafetyNetKnownIssue] = id3 + wave + flac + mp4

    /// Every MP3 save that writes the container.
    private static let mp3ContainerKinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .s1, .s2, .k15, .k16, .k17]
    /// Every MP3 save that writes the tag; a packet-only save (K15, K17) rewrites only the `PRIV`.
    private static let mp3TagKinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .s1, .s2, .k16]

    private static let id3: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3ContainerKinds, item: .id3(.majorVersion),
            text: "An MP3 save re-renders an ID3v2.3 tag as ID3v2.4: expected 2.3, found 2.4 (F7)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3ContainerKinds, item: .id3(.id3v1),
            text: "An MP3 save adds an ID3v1 tag the file did not have: expected none, found one (F7)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3TagKinds, item: .id3(.otherPopularimeter),
            text: "An MP3 tag save deletes other players' POPM frames: expected 1, found 0 (F8)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3TagKinds, item: .id3(.artist),
            text: "An MP3 tag save flattens a multi-valued TPE1: expected two values, found one joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3TagKinds, item: .id3(.userText),
            text: "An MP3 tag save upper-cases other apps' TXXX descriptions: expected \"SafetyNet Foreign\", found \"SAFETYNET FOREIGN\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3TagKinds, item: .id3(.lyrics),
            text: "An MP3 tag save rewrites other apps' USLT frames: expected language \"eng\" and description \"Safety Net\", found \"XXX\" and \"SAFETY NET\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3TagKinds, item: .id3(.userURL),
            text: "An MP3 tag save upper-cases other apps' WXXX descriptions: expected \"Safety Net Link\", found \"SAFETY NET LINK\" (F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: mp3TagKinds, item: .id3(.comments),
            text: "An MP3 tag save merges a second-language COMM into the first and rewrites a described one: expected 3 frames with languages \"eng\" and \"fra\" kept, found 2, one joined with a space and one \"XXX | SAFETY NET NOTE\" (F15, F29)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: [.k0, .k5, .k6, .s2], item: .id3(.otherPictures),
            text: "An MP3 artwork save deletes the file's other pictures: expected the back cover, found none (F26)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: [.k7, .s1], item: .id3(.tableOfContents),
            text: "An MP3 marker save leaves CTOC listing the old chapters: expected the new CHAP element IDs, found the previous ones (F10)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: [.k0], item: .id3(.frontCover),
            text: "An MP3 save flagged for artwork re-encodes an unchanged front cover: expected the same image bytes, found new ones (F30)"
        ),
    ]

    /// Every WAV save that writes tags: all but the packet-only saves, which rewrite only `_PMX`.
    private static let wavTagKinds: Set<SaveKind> = [.k0, .k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .s1, .s2, .k16]

    private static let wave: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.otherPopularimeter),
            text: "A WAV tag save deletes other players' POPM frames: expected 1, found 0 (F8)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.artist),
            text: "A WAV tag save flattens a multi-valued TPE1: expected two values, found one joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.lyrics),
            text: "A WAV tag save moves another app's USLT into a TXXX: expected the USLT frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.userURL),
            text: "A WAV tag save moves another app's WXXX into a TXXX: expected the WXXX frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.involvedPeople),
            text: "A WAV tag save moves another app's TIPL into a TXXX: expected the TIPL frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.frameIDUserText),
            text: "A WAV tag save writes USLT, WXXX and TIPL as TXXX frames named after them: expected none, found three (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.comments),
            text: "A WAV tag save drops a second undescribed COMM in another language: expected the \"fra\" frame kept beside the file's comment, found it removed (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .id3(.duplicateUserText),
            text: "A WAV tag save adds a second TXXX with a description already present: expected each description once, found one twice (F33)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds.subtracting([.k1, .k16, .s1, .s2]), item: .id3(.infoUserText),
            text: "A WAV save that edits no tag still rewrites the tags, adding an INFO item to ID3: expected no new TXXX, found TXXX NUMCOLORS (F47)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .riff(.unknownInfo),
            text: "A WAV tag save drops INFO items it has no key for: expected IFRM, found none (F20)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: wavTagKinds, item: .riff(.iXML),
            text: "A WAV tag save re-serializes iXML, dropping comments and turning CDATA into escaped text: expected the comment and CDATA nodes, found neither (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: [.k0, .k5, .k6, .s2], item: .id3(.otherPictures),
            text: "A WAV artwork save deletes the file's other pictures: expected the back cover, found none (F26)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: [.k0], item: .id3(.frontCover),
            text: "A WAV save flagged for artwork re-encodes an unchanged front cover: expected the same image bytes, found new ones (F30)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: [.k0, .k7, .k8, .s1], item: .riff(.otherAssociatedData),
            text: "A WAV marker save drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav-undated-bext"], kinds: wavTagKinds, item: .riff(.bextDateTime),
            text: "A WAV tag save fills an empty BEXT origination date and time with '0' characters: expected 18 NUL bytes, found \"000000000000000000\" (F36)"
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
            rows: ["flac"], kinds: [.k0, .k5, .k6, .s2], item: .flac(.otherPictures),
            text: "A FLAC artwork save deletes the file's other pictures: expected the back cover, found none (F26)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: [.k0], item: .flac(.frontCover),
            text: "A FLAC save flagged for artwork re-encodes an unchanged front cover: expected the same image bytes, found new ones (F30)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: [.k0], item: .flac(.chapters),
            text: "A FLAC marker save of unchanged markers turns point chapters into regions: expected no CHAPTERnnnEND, found one ending at the next chapter (F38)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac-ixml-only-bext"], kinds: [.k1, .k2, .k5], item: .flac(.blockSet),
            text: "A FLAC save writes a bext block for a BEXT held only in iXML's <BEXT>: expected no bext block, found one (F39)"
        ),
    ]

    /// Every M4A and M4B save kind in the net: each runs the tag save first.
    private static let mp4Kinds: Set<SaveKind> = [.k0, .k1, .k2, .k5, .k6, .k7, .k8, .s1, .s2]

    private static let mp4: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b"], kinds: mp4Kinds, item: .mp4(.multiValuedText),
            text: "An MP4 save flattens a multi-valued text item: expected ©ART twice, found one value joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b"], kinds: mp4Kinds, item: .mp4(.unknownFreeform),
            text: "An MP4 save upper-cases another app's iTunes freeform name: expected \"SafetyNet Foreign\", found \"SAFETYNET FOREIGN\" (F40)"
        ),
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b"], kinds: mp4Kinds, item: .mp4(.gaplessInfo),
            text: "An MP4 save renames the gapless-playback atom: expected iTunSMPB, found ITUNSMPB (F40)"
        ),
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b"], kinds: [.k0, .k5, .k6, .s2], item: .mp4(.otherCovers),
            text: "An MP4 artwork save deletes the file's other covr images: expected the second image, found none (F26)"
        ),
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b"], kinds: [.k0], item: .mp4(.frontCover),
            text: "An MP4 save flagged for artwork re-encodes an unchanged cover: expected the same image bytes, found new ones (F30)"
        ),
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b"], kinds: [.k7, .s1], item: .mp4(.chapters),
            text: "An MP4 marker save whose first marker starts after zero adds an untitled chapter at zero that other players list: expected the written chapters only, found an extra one at 0.000 (F41)"
        ),
        SafetyNetKnownIssue(
            rows: ["m4a", "m4b"], kinds: [.k8], item: .ourReader(.markers),
            text: "Removing every MP4 marker leaves the Nero chpl chapters, which the app then reads back as markers: expected none, found the chpl's five (F42)"
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
