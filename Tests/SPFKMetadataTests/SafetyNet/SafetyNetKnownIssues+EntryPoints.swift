// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// The entry-point kinds' known failures, kept beside the save kinds' table they extend.
extension SafetyNetKnownIssues {
    private static let waveRows: Set<String> = ["wav", "rf64"]
    private static let tagSave: Set<SaveKind> = [.e1, .e2]

    static let entryPoints: [SafetyNetKnownIssue] = waveEntryPoints + otherEntryPoints

    private static let waveEntryPoints: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: waveRows, kinds: [.e5], item: .riff(.otherAssociatedData),
            text: "A WAV marker write drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
    ]

    private static let otherEntryPoints: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["mka", "mkv", "webm"], kinds: tagSave, item: .matroska(.unknownTag),
            text: "A Matroska TagProperties save moves another app's untargeted tag from album to track level (F50)"
        ),
    ]
}
