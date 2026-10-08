// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// The combined kinds' known failures. Each repeats a single-flag kind's finding on the same row,
/// with that finding's text.
extension SafetyNetKnownIssues {
    static let combined: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: [.k9, .k10, .k11, .k12, .s3], item: .flac(.iXML),
            text: "A FLAC save re-serializes iXML, dropping comments and turning CDATA into escaped text: expected the comment and CDATA nodes, found neither (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["aiff"], kinds: [.k9, .k10, .k11, .k12, .s3], item: .id3(.comments),
            text: "An AIFF save merges a second-language COMM into the file's own: expected 3 frames with \"fra\" kept, found 2, \"Un commentaire\" joined to the first with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.comments),
            text: "A WAV tag save drops a second undescribed COMM in another language: expected the \"fra\" frame kept beside the file's comment, found it removed (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.comments),
            text: "An MP3 tag save merges a second-language COMM into the file's own: expected 3 frames with \"fra\" kept, found 2, \"Un commentaire\" joined to the first with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.involvedPeople),
            text: "A WAV tag save moves another app's TIPL into a TXXX: expected the TIPL frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.artist),
            text: "A WAV tag save flattens a multi-valued TPE1: expected two values, found one joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.duplicateUserText),
            text: "A WAV tag save adds a second TXXX with a description already present: expected each description once, found one twice (F33)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k11], item: .id3(.infoUserText),
            text: "A WAV save that edits no tag still rewrites the tags, adding an INFO item to ID3: expected no new TXXX, found TXXX NUMCOLORS (F47)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.frameIDUserText),
            text: "A WAV tag save writes USLT, WXXX and TIPL as TXXX frames named after them: expected none, found three (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.lyrics),
            text: "A WAV tag save moves another app's USLT into a TXXX: expected the USLT frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .id3(.userURL),
            text: "A WAV tag save moves another app's WXXX into a TXXX: expected the WXXX frame, found none (F24)"
        ),
        SafetyNetKnownIssue(
            rows: ["mka", "mkv", "webm"], kinds: [.k9], item: .matroska(.unknownTag),
            text: "A Matroska save moves another app's untargeted tag from album to track level: expected no TargetTypeValue, found 30 (F50)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .riff(.unknownInfo),
            text: "A WAV tag save drops INFO items it has no key for: expected IFRM, found none (F20)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: [.k10, .k11, .k12, .s3], item: .riff(.otherAssociatedData),
            text: "A WAV marker save drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64"], kinds: [.k10, .k11, .k12, .s3], item: .riff(.otherAssociatedData),
            text: "An RF64 marker save drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64", "wav"], kinds: [.k9, .k10, .k11, .k12, .s3, .s4], item: .riff(.iXML),
            text: "A WAV tag save re-serializes iXML, dropping comments and turning CDATA into escaped text: expected the comment and CDATA nodes, found neither (F13)"
        ),
    ]
}
