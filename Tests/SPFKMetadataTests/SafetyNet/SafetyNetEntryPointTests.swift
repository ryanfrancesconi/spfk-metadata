// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// The lower writers other callers use — TorchTag's tag save, conversion's artwork and marker
/// writes, and `MetadataPaster`'s BEXT and iXML — leave everything they do not write as it was.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetEntryPointTests: BinTestCase {
    static let rows: [SafetyNetRow] = [
        .mp3, .aac, .wav, .rf64, .aiff, .aifc, .flac, .ogg, .opus, .m4a, .m4b, .mp4, .m4v, .mov, .mka, .mkv, .webm,
    ]

    static let cases = SafetyNetCase.cases(rows: rows, kinds: [.e1, .e2, .e3, .e4, .e5, .e6, .e7, .e8, .e9])

    @Test(arguments: cases)
    func onlyTheEditedComponentChanges(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }
}
