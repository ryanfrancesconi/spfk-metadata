// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Every save the app makes to a FLAC writes what it edits and leaves the rest — the app's other
/// components, other applications' Vorbis fields, pictures and blocks, and the order of the
/// `riff` chunks a WAV is rebuilt from — as it was.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetFLACTests: BinTestCase {
    static let cases = SafetyNetCase.cases(
        rows: [SafetyNetRow.flac],
        kinds: [.k0, .k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .s1, .s2]
    ) + SafetyNetCase.cases(rows: [SafetyNetRow.flacIXMLOnlyBEXT], kinds: [.k1, .k2, .k5])

    @Test(arguments: cases)
    func onlyTheEditedComponentChanges(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }
}
