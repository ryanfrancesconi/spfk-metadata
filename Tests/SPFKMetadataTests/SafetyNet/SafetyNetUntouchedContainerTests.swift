// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Saves that route no container write — a Finder tag change and an `.xmp`-only save — must leave
/// every byte of the file as it was, and the file itself in place.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetUntouchedContainerTests: BinTestCase {
    static let cases = SafetyNetCase.cases(rows: SafetyNetRow.slice + [.rf64, .aiff, .aifc, .aac, .ogg, .opus, .mp4, .m4v, .mov], kinds: [.k13, .k14])

    @Test(arguments: cases)
    func theFileIsByteIdentical(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }
}
