// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// The entry-point kinds' known failures, kept beside the save kinds' table they extend.
extension SafetyNetKnownIssues {
    private static let tagFileRows: Set<String> = ["mp3", "aac", "aiff", "aifc"]
    private static let waveRows: Set<String> = ["wav", "rf64"]
    private static let mp4Rows: Set<String> = ["m4a", "m4b", "mp4", "m4v", "mov"]
    private static let tagSave: Set<SaveKind> = [.e1, .e2]

    static let entryPoints: [SafetyNetKnownIssue] = id3EntryPoints + waveEntryPoints + otherEntryPoints

    private static let id3EntryPoints: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: tagFileRows, kinds: tagSave, item: .id3(.artist),
            text: "A TagProperties save flattens a multi-valued TPE1: expected two values, found one joined with a space (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["mp3", "aiff"], kinds: tagSave, item: .id3(.comments),
            text: "A TagProperties save merges a second-language COMM into the file's own: expected the \"fra\" frame kept, found it joined to the first (F15)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: tagSave, item: .id3(.userText),
            text: "A WAV TagProperties save upper-cases other apps' TXXX descriptions: expected \"SafetyNet Foreign\", found \"SAFETYNET FOREIGN\" (F29)"
        ),
    ]

    /// A `TagProperties` save on a WAV takes TagLib's generic path (F52); `MetadataPaster`'s
    /// `WaveFileC` writes re-render the tag from its dictionary (F23).
    private static let waveEntryPoints: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e1, .e2, .e6, .e7], item: .id3(.artist),
            text: "A WAV TagProperties save or MetadataPaster write flattens a multi-valued TPE1: expected two values, found one joined (F15, F23)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e1, .e2, .e6, .e7], item: .id3(.comments),
            text: "A WAV TagProperties save or MetadataPaster write merges or drops other apps' COMM frames (F15, F23)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e1, .e2, .e6, .e7], item: .id3(.lyrics),
            text: "A WAV TagProperties save rewrites another app's USLT, and a MetadataPaster write moves it into a TXXX (F29, F24, F23)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e1, .e2, .e6, .e7], item: .id3(.userURL),
            text: "A WAV TagProperties save upper-cases another app's WXXX, and a MetadataPaster write moves it into a TXXX (F29, F24, F23)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e6, .e7], item: .id3(.involvedPeople),
            text: "A WAV MetadataPaster write moves another app's TIPL into a TXXX: expected the TIPL frame, found none (F24, F23)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e6, .e7], item: .id3(.frameIDUserText),
            text: "A WAV MetadataPaster write writes USLT, WXXX and TIPL as TXXX frames named after them (F24, F23)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: tagSave, item: .id3(.otherPopularimeter),
            text: "A WAV TagProperties save drops other players' POPM frames: expected 1, found 0 (F52)"
        ),
        SafetyNetKnownIssue(rows: waveRows, kinds: tagSave, item: .id3(.playCount), text: "A WAV TagProperties save drops PCNT (F52)"),
        SafetyNetKnownIssue(rows: waveRows, kinds: tagSave, item: .id3(.privateFrame), text: "A WAV TagProperties save drops other apps' PRIV frames (F52)"),
        SafetyNetKnownIssue(rows: waveRows, kinds: tagSave, item: .id3(.generalObject), text: "A WAV TagProperties save drops GEOB (F52)"),
        SafetyNetKnownIssue(rows: waveRows, kinds: tagSave, item: .id3(.uniqueFileID), text: "A WAV TagProperties save drops UFID (F52)"),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: tagSave, item: .riff(.infoRating),
            text: "A WAV TagProperties save removes the IRTD rating mirror: expected \"4\", found none (F52)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: tagSave, item: .riff(.infoComment),
            text: "A WAV TagProperties save appends another app's second comment to ICMT (F52, F15)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: tagSave, item: .riff(.otherInfo),
            text: "A WAV TagProperties save drops IENG and IPLT and renames ITRK to IPRT (F52)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: tagSave, item: .riff(.unknownInfo),
            text: "A WAV TagProperties save drops INFO items it has no key for: expected IFRM, found none (F52, F20)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e7], item: .riff(.iXML),
            text: "A WAV iXML write takes our reader's re-serialized document, losing comments and CDATA (F13)"
        ),
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e5], item: .riff(.otherAssociatedData),
            text: "A WAV marker write drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
    ]

    private static let otherEntryPoints: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: tagSave, item: .flac(.multiValuedField),
            text: "A FLAC TagProperties save flattens a repeated Vorbis field: expected ENCODER twice, found one value (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["flac"], kinds: [.e9], item: .flac(.iXML),
            text: "A FLAC iXML write takes our reader's re-serialized document, losing comments and CDATA (F13)"
        ),
        SafetyNetKnownIssue(
            rows: ["ogg", "opus"], kinds: tagSave, item: .ogg(.multiValuedField),
            text: "An Ogg TagProperties save flattens a repeated comment field: expected ENCODER twice, found one value (F15)"
        ),
        SafetyNetKnownIssue(
            rows: mp4Rows, kinds: tagSave, item: .mp4(.multiValuedText),
            text: "An MP4 TagProperties save flattens a multi-valued text item: expected ©ART twice, found one value (F15)"
        ),
        SafetyNetKnownIssue(
            rows: ["mka", "mkv", "webm"], kinds: tagSave, item: .matroska(.unknownTag),
            text: "A Matroska TagProperties save moves another app's untargeted tag from album to track level (F50)"
        ),
    ]
}
