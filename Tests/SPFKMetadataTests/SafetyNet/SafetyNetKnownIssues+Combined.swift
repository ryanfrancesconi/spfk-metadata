// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// The combined kinds' known failures. Each repeats a single-flag kind's finding on the same row,
/// with that finding's text.
extension SafetyNetKnownIssues {
    static let combined: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["mka", "mkv", "webm"], kinds: [.k9], item: .matroska(.unknownTag),
            text: "A Matroska save moves another app's untargeted tag from album to track level: expected no TargetTypeValue, found 30 (F50)"
        ),
        SafetyNetKnownIssue(
            rows: ["wav"], kinds: [.k10, .k11, .k12, .s3], item: .riff(.otherAssociatedData),
            text: "A WAV marker save drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
        SafetyNetKnownIssue(
            rows: ["rf64"], kinds: [.k10, .k11, .k12, .s3], item: .riff(.otherAssociatedData),
            text: "An RF64 marker save drops other apps' adtl note and ltxt chunks: expected both, found none (F35)"
        ),
    ]
}
