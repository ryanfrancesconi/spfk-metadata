// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBench
import SPFKMetadata
import SPFKMetadataBase

/// Parse and save cases for the formats other than WAV, each on an encoder-fresh master. `save-all`
/// is the widest save (title, artwork and markers together); `save-all-again` repeats it on a file
/// already saved once, which is where padding decides whether the audio is rewritten.
struct FormatBench {
    let corpus: FormatCorpus
    let cases: SaveCases

    func run(into run: inout RegressionRun) async throws {
        for format in BenchFormat.allCases {
            let master = try corpus.write(format)
            let kib = (try FileManager.default.attributesOfItem(atPath: master.path)[.size] as? Int ?? 0) / 1024
            FileHandle.standardError.write(Data("  \(format.rawValue): master \(kib) KiB\n".utf8))
            await measure(format, master: master, into: &run)
            try FileManager.default.removeItem(at: master)
            try? FileManager.default.removeItem(at: cases.work(for: master))
        }
    }

    private func measure(_ format: BenchFormat, master: URL, into run: inout RegressionRun) async {
        let prefix = "\(format.rawValue).fresh"

        await cases.parse("\(prefix).parse", master, into: &run)
        await cases.save("\(prefix).save-metadata", master, [.metadata], cases.editTitle, into: &run)
        await cases.save("\(prefix).save-image", master, [.image], cases.editArtwork, into: &run)
        await cases.save("\(prefix).save-markers", master, [.markers], cases.editMarkers, into: &run)
        await cases.save("\(prefix).save-all", master, [.metadata, .image, .markers], cases.editAll, into: &run)
        await cases.save("\(prefix).save-all-again", master, [.metadata, .image, .markers], firstSave: true, cases.editAll, into: &run)
    }
}
