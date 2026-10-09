// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBench
import SPFKMetadata
import SPFKMetadataBase

/// WAV parse and save cases, one master per layout.
struct WAVBench {
    let corpus: WAVCorpus
    let cases: SaveCases
    /// Prints each save's chunk layout afterwards.
    let showsLayout: Bool

    func run(into run: inout RegressionRun) async throws {
        for layout in WAVLayout.allCases {
            let master = try corpus.write(layout)
            await measure(layout, master: master, into: &run)
            try FileManager.default.removeItem(at: master)
        }
        try? FileManager.default.removeItem(at: cases.work(for: corpus.url(for: .recorder)))
    }

    private func measure(_ layout: WAVLayout, master: URL, into run: inout RegressionRun) async {
        let prefix = "wav.\(layout.rawValue)"

        await cases.parse("\(prefix).parse", master, into: &run)

        switch layout {
        case .recorder:
            await save("\(prefix).save-metadata", master, [.tags], cases.editTitle, into: &run)
            await save("\(prefix).save-metadata-markers", master, [.tags, .markers], { cases.editTitle(&$0); cases.editMarkers(&$0) }, into: &run)
            await cases.sequentialRewrite("io.sequential-rewrite", of: master, into: &run)

        case .trailing:
            await save("\(prefix).save-metadata", master, [.tags], cases.editTitle, into: &run)
            await save("\(prefix).save-markers", master, [.markers], cases.editMarkers, into: &run)
            await save("\(prefix).save-finder-tags", master, [.finderTags], { _ in }, into: &run)
            await save("\(prefix).save-image", master, [.artwork], cases.editArtwork, into: &run)

        case .trailingArt:
            await save("\(prefix).save-metadata", master, [.tags], cases.editTitle, into: &run)
            await save("\(prefix).save-metadata-image-unchanged", master, [.tags, .artwork], cases.editTitle, into: &run)

        case .rf64:
            await save("\(prefix).save-metadata", master, [.tags], cases.editTitle, into: &run)
            await save("\(prefix).save-markers", master, [.markers], cases.editMarkers, into: &run)
        }
    }

    private func save(
        _ id: String,
        _ master: URL,
        _ flags: Set<MetadataDirtyFlag>,
        _ edit: @escaping (inout MetaAudioFileDescription) throws -> Void,
        into run: inout RegressionRun
    ) async {
        await cases.save(id, master, flags, edit, into: &run)

        let work = cases.work(for: master)
        if showsLayout, let before = try? RIFFLayout(url: master), let after = try? RIFFLayout(url: work) {
            let moved = before.dataOffset == after.dataOffset ? "" : "   data moved \(before.dataOffset ?? 0) → \(after.dataOffset ?? 0)"
            FileHandle.standardError.write(Data("      after: \(after)\(moved)\n".utf8))
        }
    }
}
