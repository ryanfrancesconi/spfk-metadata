// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

/// Every save the app makes to a Matroska or WebM file writes what it edits and leaves the rest —
/// the app's other components, other applications' tags at every level, chapters and attachments,
/// and the clusters — as it was.
@Suite(.tags(.file, .metadataSafetyNet))
final class SafetyNetMatroskaTests: BinTestCase {
    static let cases = SafetyNetCase.cases(
        rows: [SafetyNetRow.mka, SafetyNetRow.mkv, SafetyNetRow.webm],
        kinds: [.k0, .k1, .k2, .k5, .k6, .s2]
    )

    @Test(arguments: cases)
    func onlyTheEditedComponentChanges(_ testCase: SafetyNetCase) async throws {
        try await SafetyNetCell.run(testCase, in: bin)
    }

    /// The editor the plant uses: a grown element moves to the end, the SeekHead follows it, the
    /// Segment's size covers it, and no Cluster moves.
    @Test func aGrownElementMovesToTheEndAndTheSeekHeadFollows() throws {
        let url = bin.appendingPathComponent("tabla.mka")
        try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_mka, to: url)
        let before = try MatroskaElements(contentsOf: url)

        try MatroskaSegmentEditor.rewrite(url, grow: [(MatroskaElements.ID.tags, SafetyNetMatroskaForeign.unknownTag)], append: [])

        let data = try Data(contentsOf: url)
        let after = try MatroskaElements(data)
        let tags = try #require(after.elements(MatroskaElements.ID.tags).first)
        let seek = try #require(after.seekEntries.first { $0.id == MatroskaElements.ID.tags })

        #expect(after.segment.offset + after.segment.size == data.count)
        #expect(Int(seek.position) + after.segmentDataOffset == tags.offset)
        #expect(after.segment.children.last?.id == MatroskaElements.ID.tags)
        #expect(after.elements(MatroskaElements.ID.cluster) == before.elements(MatroskaElements.ID.cluster))
        #expect(after.tags.count == before.tags.count + 1)
        #expect(after.tags.last?.simpleTags.map(\.name) == [SafetyNetMatroskaForeign.unknownTagName])
    }
}
