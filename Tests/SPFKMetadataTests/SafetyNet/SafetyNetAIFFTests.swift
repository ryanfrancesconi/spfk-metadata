// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Every save the app makes to an AIFF writes what it edits and leaves the rest — the app's other
/// components, other applications' ID3 frames, text, comments and application chunks — as it was.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetAIFFTests: BinTestCase {
    static let cases = SafetyNetCase.cases(
        rows: [SafetyNetRow.aiff, SafetyNetRow.aifc],
        kinds: [.k0, .k1, .k2, .k5, .k6, .k7, .k8, .s1, .s2]
    )

    @Test(arguments: cases)
    func onlyTheEditedComponentChanges(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }
}
