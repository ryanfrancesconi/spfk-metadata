// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Every save the app makes to an MP3 writes what it edits and leaves the rest of the ID3v2 tag —
/// the app's other components, other applications' frames, and the tag's version — as it was.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetID3Tests: BinTestCase {
    static let cases = SafetyNetCase.cases(
        rows: [SafetyNetRow.mp3],
        kinds: [.k0, .k1, .k2, .k5, .k6, .k7, .s1, .s2, .k15, .k16, .k17]
    )

    @Test(arguments: cases)
    func onlyTheEditedComponentChanges(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }
}
