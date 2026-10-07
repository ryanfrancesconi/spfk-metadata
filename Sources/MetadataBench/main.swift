// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBench

// File I/O measurements for the metadata parse and save paths, compiled `-O`.
//
//   spfk-metadata-bench regress --json <out>   the fixed case set bench.sh compares; corpus written
//                                              into METADATA_BENCH_DIR
//   spfk-metadata-bench wav|formats [--size-mib N] [--iterations N] [--dir <path>]
//                                              the WAV or the other formats' cases at any audio
//                                              size; `wav` prints each save's chunk layout
//
// A regression case id is never renamed or reshaped without a new corpus id in bench.sh.

let arguments = CommandLine.arguments

func value(after flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

/// The audio size of the regression corpus. Changing it changes every case: new corpus id.
let regressionAudioMiB = 64

func makeCases(in directory: URL, iterations: Int, warmup: Int) throws -> SaveCases {
    let coverURL = directory.appendingPathComponent("cover.jpg")
    try BenchCover.write(to: coverURL)
    return SaveCases(directory: directory, coverURL: coverURL, iterations: iterations, warmup: warmup)
}

func makeDirectory(_ path: String?) throws -> URL {
    let url = path.map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("spfk-metadata-bench-\(ProcessInfo.processInfo.processIdentifier)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

do {
    let mode = arguments.dropFirst().first

    switch mode {
    case "regress":
        guard let path = ProcessInfo.processInfo.environment["METADATA_BENCH_DIR"] else {
            throw BenchError("METADATA_BENCH_DIR unset")
        }
        let directory = try makeDirectory(path)
        let cases = try makeCases(in: directory, iterations: 5, warmup: 1)
        var run = RegressionRun(bench: "metadata")
        try await WAVBench(corpus: WAVCorpus(directory: directory, audioBytes: regressionAudioMiB << 20, coverURL: cases.coverURL), cases: cases, showsLayout: false).run(into: &run)
        try await FormatBench(corpus: FormatCorpus(directory: directory, pcmBytes: regressionAudioMiB << 20), cases: cases).run(into: &run)
        try run.write()

    case "wav", "formats":
        let sizeMiB = value(after: "--size-mib").flatMap(Int.init) ?? regressionAudioMiB
        let iterations = value(after: "--iterations").flatMap(Int.init) ?? 3
        let directory = try makeDirectory(value(after: "--dir"))
        defer { try? FileManager.default.removeItem(at: directory) }

        let counting = IOCounters.isCounting ? "" : " -- I/O not counted, run with bench-open-counter injected"
        FileHandle.standardError.write(Data("\(mode ?? ""), \(sizeMiB) MiB of audio, \(iterations) iterations\(counting)\n".utf8))

        let cases = try makeCases(in: directory, iterations: iterations, warmup: 0)
        var run = RegressionRun(bench: "metadata")
        if mode == "wav" {
            try await WAVBench(corpus: WAVCorpus(directory: directory, audioBytes: sizeMiB << 20, coverURL: cases.coverURL), cases: cases, showsLayout: true).run(into: &run)
        } else {
            try await FormatBench(corpus: FormatCorpus(directory: directory, pcmBytes: sizeMiB << 20), cases: cases).run(into: &run)
        }

    default:
        print("usage: spfk-metadata-bench regress --json <out> | wav|formats [--size-mib N] [--iterations N] [--dir <path>]")
        exit(64)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
