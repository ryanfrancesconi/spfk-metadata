// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Every save the app makes to an Ogg Vorbis or Opus file writes what it edits and leaves the rest
/// — the app's other components, other applications' comment fields and pictures, the vendor
/// string and the audio pages — as it was.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetOggTests: BinTestCase {
    static let cases = SafetyNetCase.cases(
        rows: [SafetyNetRow.ogg, SafetyNetRow.opus],
        kinds: [.k0, .k1, .k2, .k5, .k6, .k7, .k8, .s1, .s2]
    )

    @Test(arguments: cases)
    func onlyTheEditedComponentChanges(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }

    /// The comment writer the plant uses: an unchanged comment reproduces the file.
    @Test(arguments: ["tabla.ogg", "sine.opus"])
    func anUnchangedCommentRewritesByteForByte(name: String) throws {
        let source = name == "tabla.ogg" ? TestBundleResources.shared.tabla_ogg : TestBundleResources.shared.sine_opus
        let url = bin.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: url)

        try OggCommentWriter.rewrite(url) { ($0.vendor, $0.fields) }

        #expect(try Data(contentsOf: url) == Data(contentsOf: source))
    }
}
