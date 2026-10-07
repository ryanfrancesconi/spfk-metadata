// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Saves carrying several flags at once, and sequences saved from one description without a
/// reparse, write what each part edits and leave the rest as the single-flag saves do.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetCombinedKindTests: BinTestCase {
    static let cases = SafetyNetCase.cases(rows: SafetyNetEntryPointTests.rows, kinds: [.k9, .k10, .k11, .k12, .s3, .s4])

    @Test(arguments: cases)
    func onlyTheEditedComponentsChange(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }
}
