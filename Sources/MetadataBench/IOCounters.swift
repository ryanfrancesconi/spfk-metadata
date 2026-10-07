// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Darwin
import Foundation

/// What the corpus files saw, from the interposer `bench.sh` injects
/// (`scripts/bench-open-counter.c`): opens of, and bytes written to, paths under
/// `SPFK_BENCH_COUNT_OPENS_UNDER`. Both read as -1 when it is absent.
enum IOCounters {
    private typealias Counter = @convention(c) () -> Int

    private static func counter(_ name: String) -> Counter? {
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: Counter.self) }
    }

    private static let openCount = counter("spfk_bench_open_count")
    private static let bytesWritten = counter("spfk_bench_bytes_written")

    static var isCounting: Bool {
        openCount != nil && bytesWritten != nil
    }

    static func opens() -> Int {
        openCount?() ?? -1
    }

    static func written() -> Int {
        bytesWritten?() ?? -1
    }

    /// Clones `source` to `destination` (APFS copy-on-write), replacing it.
    static func clone(_ source: URL, to destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        guard clonefile(source.path, destination.path, 0) == 0 else {
            throw BenchError("clonefile \(source.lastPathComponent): \(String(cString: strerror(errno)))")
        }
    }
}
