// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Times two tag saves on a copy of the file named by `SPFK_LARGE_MP4` (as
/// `TEST_RUNNER_SPFK_LARGE_MP4` under `xcodebuild`): one that fits the padding beside `ilst`, and
/// one that outgrows it and so has to move `mdat`. Point it at a feature-length `.m4v`/`.mov`.
@Suite(.tags(.development), .enabled(if: LargeMP4Fixture.url != nil))
final class TagFileLargeMP4DevelopmentTests: BinTestCase {
    @Test func timeSaves() throws {
        let source = try #require(LargeMP4Fixture.url)
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)

        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        print("LARGE: \(url.lastPathComponent) \(size) bytes")

        for (label, comment) in [
            ("fits padding", "a"),
            ("outgrows padding", String(repeating: "b", count: 64 * 1024)),
        ] {
            var properties = try TagProperties(url: url)
            properties.set(tag: .comment, value: comment)

            let start = Date()
            try properties.save(to: url)
            print("LARGE: save (\(label)) took \(String(format: "%.2f", Date().timeIntervalSince(start))) s")
        }
    }
}

enum LargeMP4Fixture {
    static var url: URL? {
        guard let path = ProcessInfo.processInfo.environment["SPFK_LARGE_MP4"], path.isEmpty == false else {
            return nil
        }

        let url = URL(fileURLWithPath: path)

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
