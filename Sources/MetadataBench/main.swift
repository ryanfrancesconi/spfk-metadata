// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBench

// File I/O measurements for the metadata parse and save paths, compiled `-O`.
//
//   spfk-metadata-bench regress --json <out>   the fixed case set bench.sh compares; corpus written
//                                              into METADATA_BENCH_DIR
//   spfk-metadata-bench wav [--size-mib N] [--iterations N] [--dir <path>]
//                                              the same cases at any audio size, with each save's
//                                              chunk layout printed
//
// A regression case id is never renamed or reshaped without a new corpus id in bench.sh.

let arguments = CommandLine.arguments

func value(after flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

/// The audio size of the regression corpus. Changing it changes every case: new corpus id.
let regressionAudioMiB = 64

func makeDirectory(_ path: String?) throws -> URL {
    let url = path.map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("spfk-metadata-bench-\(ProcessInfo.processInfo.processIdentifier)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

do {
    switch arguments.dropFirst().first {
    case "regress":
        var run = RegressionRun(bench: "metadata")
        guard let path = ProcessInfo.processInfo.environment["METADATA_BENCH_DIR"] else {
            throw BenchError("METADATA_BENCH_DIR unset")
        }
        let corpus = try WAVCorpus(directory: makeDirectory(path), audioBytes: regressionAudioMiB << 20)
        try await WAVBench(corpus: corpus, iterations: 5, warmup: 1, showsLayout: false).run(into: &run)
        try run.write()

    case "wav":
        let sizeMiB = value(after: "--size-mib").flatMap(Int.init) ?? regressionAudioMiB
        let iterations = value(after: "--iterations").flatMap(Int.init) ?? 3
        let directory = try makeDirectory(value(after: "--dir"))
        defer { try? FileManager.default.removeItem(at: directory) }

        let counting = IOCounters.isCounting ? "" : " -- I/O not counted, run with bench-open-counter injected"
        FileHandle.standardError.write(Data("WAV, \(sizeMiB) MiB of audio, \(iterations) iterations\(counting)\n".utf8))
        var run = RegressionRun(bench: "metadata")
        let corpus = try WAVCorpus(directory: directory, audioBytes: sizeMiB << 20)
        try await WAVBench(corpus: corpus, iterations: iterations, warmup: 0, showsLayout: true).run(into: &run)

    default:
        print("usage: spfk-metadata-bench regress --json <out> | wav [--size-mib N] [--iterations N] [--dir <path>]")
        exit(64)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
