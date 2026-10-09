// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBench
import SPFKMetadata
import SPFKMetadataBase

/// The parse and save measurements every format's cases share. A parse counts the opens it made;
/// a save counts the KiB it wrote. Every save runs on a fresh APFS clone of its master, so a "first
/// save" is always one — and the master's pages are cached, so these are warm-cache numbers.
struct SaveCases {
    let directory: URL
    let coverURL: URL
    let iterations: Int
    let warmup: Int

    func work(for master: URL) -> URL {
        directory.appendingPathComponent("work.\(master.pathExtension)")
    }

    func parse(_ id: String, _ master: URL, into run: inout RegressionRun) async {
        await run.measure(id, iterations: iterations, warmup: warmup) {
            let before = IOCounters.opens()
            _ = try await MetaAudioFileDescription(parsing: master)
            return IOCounters.isCounting ? IOCounters.opens() - before : -1
        }
    }

    /// `firstSave`, when given, is applied and saved untimed before the timed save, so the case
    /// measures a file the app has already saved once.
    func save(
        _ id: String,
        _ master: URL,
        _ flags: Set<MetadataDirtyFlag>,
        firstSave: Bool = false,
        _ edit: @escaping (inout MetaAudioFileDescription) throws -> Void,
        into run: inout RegressionRun
    ) async {
        let work = work(for: master)

        await run.measure(id, iterations: iterations, warmup: warmup, prepare: {
            try IOCounters.clone(master, to: work)
            var description = try await MetaAudioFileDescription(parsing: work)
            if firstSave {
                try edit(&description)
                try description.save(dirtyFlags: flags)
                description = try await MetaAudioFileDescription(parsing: work)
            }
            try edit(&description)
            return description
        }) { description in
            var description = description
            let before = IOCounters.written()
            try description.save(dirtyFlags: flags)
            return IOCounters.isCounting ? (IOCounters.written() - before) / 1024 : -1
        }
    }

    /// One full rewrite's cost: read the file and write a copy through a 1 MiB buffer. The
    /// reference a save that moves the audio is measured against.
    func sequentialRewrite(_ id: String, of master: URL, into run: inout RegressionRun) async {
        let work = work(for: master)

        await run.measure(id, iterations: iterations, warmup: warmup, prepare: {
            try? FileManager.default.removeItem(at: work)
        }) {
            let input = try FileHandle(forReadingFrom: master)
            defer { try? input.close() }
            FileManager.default.createFile(atPath: work.path, contents: nil)
            let output = try FileHandle(forWritingTo: work)
            defer { try? output.close() }

            var total = 0
            while let block = try input.read(upToCount: 1 << 20), !block.isEmpty {
                try output.write(contentsOf: block)
                total += block.count
            }
            return total >> 20
        }
    }

    // MARK: - Edits

    /// A distinct title each call, so a repeated save is never a no-op.
    func editTitle(_ description: inout MetaAudioFileDescription) {
        let previous = description.tagProperties[.title] ?? ""
        description.tagProperties[.title] = previous == "Edited title" ? "Edited title again" : "Edited title"
    }

    func editMarkers(_ description: inout MetaAudioFileDescription) {
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "First", startTime: 0.1),
            AudioMarkerDescription(name: "Second", startTime: 0.2),
        ])
    }

    func editArtwork(_ description: inout MetaAudioFileDescription) throws {
        guard let artwork = EmbeddedArtwork(contentsOf: coverURL) else {
            throw BenchError("could not read \(coverURL.lastPathComponent)")
        }
        description.artwork.cgImage = artwork.cgImage
    }

    func editAll(_ description: inout MetaAudioFileDescription) throws {
        editTitle(&description)
        editMarkers(&description)
        try editArtwork(&description)
    }
}
