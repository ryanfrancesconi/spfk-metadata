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
    ]
}
