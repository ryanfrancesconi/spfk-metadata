// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// What `MetaAudioFileDescription(parsing:)` makes of every bundled audio and video fixture,
/// compared with a checked-in golden file, so any change to a parse is a reviewed diff.
///
/// A missing golden is written and the test fails; delete a golden to re-record it. MXF is left
/// out: it parses only after a process-wide registration another suite makes, so its golden would
/// depend on test order (`MetaAudioFileDescriptionMXFTests` covers it).
@Suite(.tags(.file))
struct ParseGoldenTests {
    static let goldenDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("ParseGolden")

    static let mediaExtensions: Set<String> = [
        "aac", "aif", "aifc", "au", "avi", "caf", "flac", "m4a", "m4b", "m4v", "mka", "mkv", "mov", "mp3",
        "mp4", "ogg", "opus", "snd", "ts", "w64", "wav", "webm", "wma", "wmv", "wv",
    ]

    static let fixtures: [String] = {
        let resources = TestBundleResources.shared
        let directories = Set([resources.tabla_wav, resources.sample_mkv].map { $0.deletingLastPathComponent() })

        return directories.flatMap { directory in
            (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        }
        .filter { mediaExtensions.contains($0.pathExtension.lowercased()) }
        .map(\.path)
        .sorted()
    }()

    @Test func everyMediaFixtureIsCovered() {
        #expect(Self.fixtures.count > 60, "found \(Self.fixtures.count) fixtures")
    }

    @Test(arguments: fixtures)
    func parseMatchesGolden(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        let actual = try await Self.dump(of: url)
        let golden = Self.goldenDirectory.appendingPathComponent(url.lastPathComponent + ".json")

        guard FileManager.default.fileExists(atPath: golden.path) else {
            try FileManager.default.createDirectory(at: Self.goldenDirectory, withIntermediateDirectories: true)
            try actual.write(to: golden, atomically: true, encoding: .utf8)
            Issue.record("Recorded \(golden.lastPathComponent); review it and re-run")
            return
        }

        let expected = try String(contentsOf: golden, encoding: .utf8)

        let expectedLines = expected.components(separatedBy: "\n")
        let actualLines = actual.components(separatedBy: "\n")
        let line = zip(expectedLines, actualLines).enumerated().first { $0.element.0 != $0.element.1 }?.offset
            ?? min(expectedLines.count, actualLines.count)

        #expect(
            actual == expected,
            """
            \(url.lastPathComponent) differs from its golden at line \(line + 1): \
            expected \(expectedLines.indices.contains(line) ? expectedLines[line] : "end of file"), \
            got \(actualLines.indices.contains(line) ? actualLines[line] : "end of file")
            """
        )
    }

    /// The description's own encoding without what belongs to this machine (the path and URL
    /// properties), plus what its encoding leaves out: the artwork's size, type and whether a
    /// thumbnail was made. A failed component read is encoded as `readFailures`, so a fixture that
    /// reads cleanly shows none.
    static func dump(of url: URL) async throws -> String {
        let parsed: MetaAudioFileDescription

        do {
            parsed = try await MetaAudioFileDescription(parsing: url)
        } catch {
            return "parse throws: \(String(describing: type(of: error)))\n"
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let encoded = try encoder.encode(parsed)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            return "not an object\n"
        }

        object["url"] = nil
        object["urlProperties"] = nil

        // A dictionary keyed by `TagKey` encodes as an alternating key/value array in hash order.
        if var tagProperties = object["tagProperties"] as? [String: Any], var tagData = tagProperties["data"] as? [String: Any] {
            tagData["tags"] = Dictionary(uniqueKeysWithValues: parsed.tagProperties.tags.map { ($0.key.rawValue, $0.value) })
            tagProperties["data"] = tagData
            object["tagProperties"] = tagProperties
        }

        let image = parsed.artwork
        object["imageDescription"] = [
            "description": image.description == url.path ? "<file path>" : image.description.map { $0 as Any } ?? NSNull(),
            "size": image.cgImage.map { "\($0.width)x\($0.height)" as Any } ?? NSNull(),
            "hasThumbnail": image.thumbnailData != nil,
        ] as [String: Any]

        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: url.path, with: "<file path>") + "\n"
    }
}
