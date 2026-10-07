// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBench
import SPFKMetadata
import SPFKMetadataBase
import SPFKMetadataC

/// WAV parse and save cases over a generated corpus. A parse case counts the opens it made; a
/// save case counts the KiB it wrote. Every save runs on a fresh APFS clone of its layout's
/// master, so a "first save" is always one — and the master's pages are cached, so these are
/// warm-cache numbers.
struct WAVBench {
    let corpus: WAVCorpus
    let iterations: Int
    let warmup: Int
    /// Prints each save's chunk layout afterwards.
    let showsLayout: Bool

    private var work: URL { corpus.directory.appendingPathComponent("work.wav") }

    func run(into run: inout RegressionRun) async throws {
        for layout in WAVLayout.allCases {
            let master = try corpus.write(layout)
            try await measure(layout, master: master, into: &run)
            try FileManager.default.removeItem(at: master)
        }
        try? FileManager.default.removeItem(at: work)
    }

    private func measure(_ layout: WAVLayout, master: URL, into run: inout RegressionRun) async throws {
        let prefix = "wav.\(layout.rawValue)"

        await run.measure("\(prefix).parse", iterations: iterations, warmup: warmup) {
            let before = IOCounters.opens()
            _ = try await MetaAudioFileDescription(parsing: master)
            return IOCounters.isCounting ? IOCounters.opens() - before : -1
        }

        switch layout {
        case .recorder:
            await save("\(prefix).save-metadata", master, [.metadata], editTitle, into: &run)
            await save("\(prefix).save-metadata-markers", master, [.metadata, .markers], { editTitle(&$0); editMarkers(&$0) }, into: &run)
            await measureSequentialRewrite(of: master, into: &run)

        case .trailing:
            await save("\(prefix).save-metadata", master, [.metadata], editTitle, into: &run)
            await save("\(prefix).save-markers", master, [.markers], editMarkers, into: &run)
            await save("\(prefix).save-finder-tags", master, [.finderTags], { _ in }, into: &run)
            await save("\(prefix).save-image", master, [.image], editArtwork, into: &run)

        case .trailingArt:
            await save("\(prefix).save-metadata", master, [.metadata], editTitle, into: &run)
            await save("\(prefix).save-metadata-image-unchanged", master, [.metadata, .image], editTitle, into: &run)

        case .rf64:
            await save("\(prefix).save-metadata", master, [.metadata], editTitle, into: &run)
            await save("\(prefix).save-markers", master, [.markers], editMarkers, into: &run)
        }
    }

    // MARK: - Cases

    private func save(
        _ id: String,
        _ master: URL,
        _ flags: Set<MetadataDirtyFlag>,
        _ edit: @escaping (inout MetaAudioFileDescription) throws -> Void,
        into run: inout RegressionRun
    ) async {
        let work = work

        await run.measure(id, iterations: iterations, warmup: warmup, prepare: {
            try IOCounters.clone(master, to: work)
            var description = try await MetaAudioFileDescription(parsing: work)
            try edit(&description)
            return description
        }) { description in
            var description = description
            let before = IOCounters.written()
            try description.save(dirtyFlags: flags)
            return IOCounters.isCounting ? (IOCounters.written() - before) / 1024 : -1
        }

        if showsLayout, let before = try? RIFFLayout(url: master), let after = try? RIFFLayout(url: work) {
            let moved = before.dataOffset == after.dataOffset ? "" : "   data moved \(before.dataOffset ?? 0) → \(after.dataOffset ?? 0)"
            FileHandle.standardError.write(Data("      after: \(after)\(moved)\n".utf8))
        }
    }

    /// One full rewrite's cost: read the file and write a copy through a 1 MiB buffer. The
    /// reference a save that moves the audio is measured against.
    private func measureSequentialRewrite(of master: URL, into run: inout RegressionRun) async {
        let work = work

        await run.measure("io.sequential-rewrite", iterations: iterations, warmup: warmup, prepare: {
            try? FileManager.default.removeItem(at: work)
        }) {
            let input = try FileHandle(forReadingFrom: master)
            defer { try? input.close() }
            FileManager.default.createFile(atPath: work.path, contents: nil)
            let output = try FileHandle(forWritingTo: work)
            defer { try? output.close() }

            var total = 0
            while let block = try input.read(upToCount: 1 << 20), block.isNotEmpty {
                try output.write(contentsOf: block)
                total += block.count
            }
            return total >> 20
        }
    }

    // MARK: - Edits

    private func editTitle(_ description: inout MetaAudioFileDescription) {
        description.tagProperties[.title] = "Edited title"
    }

    private func editMarkers(_ description: inout MetaAudioFileDescription) {
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "First", startTime: 0.1),
            AudioMarkerDescription(name: "Second", startTime: 0.2),
        ])
    }

    private func editArtwork(_ description: inout MetaAudioFileDescription) throws {
        guard let picture = TagPictureRef(url: corpus.artworkURL, pictureDescription: "", pictureType: "") else {
            throw BenchError("could not read \(corpus.artworkURL.lastPathComponent)")
        }
        description.imageDescription.pictureRef = picture
    }
}

private extension Data {
    var isNotEmpty: Bool { !isEmpty }
}
