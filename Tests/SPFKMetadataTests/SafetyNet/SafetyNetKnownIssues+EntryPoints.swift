// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// The entry-point kinds' known failures, kept beside the save kinds' table they extend.
extension SafetyNetKnownIssues {
    private static let tagSave: Set<SaveKind> = [.e1, .e2]

    static let entryPoints: [SafetyNetKnownIssue] = [
        SafetyNetKnownIssue(
            rows: ["mka", "mkv", "webm"], kinds: tagSave, item: .matroska(.unknownTag),
            text: "A Matroska TagProperties save moves another app's untargeted tag from album to track level"
        ),
    ]
}
