// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Every save the app makes to a WAV writes what it edits and leaves the rest — the app's other
/// components, other applications' ID3 frames, INFO items, chunks and marker text — as it was.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetRIFFTests: BinTestCase {
    static let cases = SafetyNetCase.cases(
        rows: [SafetyNetRow.wav, SafetyNetRow.wavUndatedBEXT],
        kinds: [.k0, .k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .s1, .s2, .k15, .k16, .k17]
    )

    @Test(arguments: cases)
    func onlyTheEditedComponentChanges(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }
}
