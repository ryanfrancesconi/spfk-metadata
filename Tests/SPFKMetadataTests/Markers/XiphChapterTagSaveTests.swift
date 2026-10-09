// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// Xiph chapter fields (`CHAPTER000`, `CHAPTER000NAME`, …) are markers: the tag path neither reads,
/// writes nor copies them.
@Suite(.tags(.file))
final class XiphChapterTagSaveTests: BinTestCase {
    static let fixtures = [TestBundleResources.shared.tabla_flac, TestBundleResources.shared.tabla_ogg]

    private func chapters(in url: URL) -> [ChapterMarker] {
        XiphChapterUtil.read(url.path) as? [ChapterMarker] ?? []
    }

    private func chapterSummary(in url: URL) -> [String] {
        chapters(in: url).map { "\($0.name ?? "")@\($0.startTime)" }
    }

    @Test(arguments: fixtures)
    func chapterFieldsAreNotReadAsTags(source: URL) throws {
        let url = try copyToBin(url: source)
        try #require(chapters(in: url).isNotEmpty)

        let properties = try TagProperties(url: url)

        #expect(properties.customTags.keys.filter { $0.uppercased().hasPrefix("CHAPTER") }.isEmpty)
    }

    @Test(arguments: fixtures)
    func aTagsOnlySaveKeepsTheChapters(source: URL) async throws {
        let url = try copyToBin(url: source)
        let before = chapterSummary(in: url)
        try #require(before.isNotEmpty)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Saved Title"
        try description.save(dirtyFlags: [.tags])

        #expect(chapterSummary(in: url) == before)
        #expect(try TagProperties(url: url)[.title] == "Saved Title")
    }

    /// Chapter keys a caller still carries as custom tags don't overwrite the chapters on disk.
    @Test(arguments: fixtures)
    func chapterCustomTagsAreNotWritten(source: URL) throws {
        let url = try copyToBin(url: source)
        let before = chapterSummary(in: url)
        try #require(before.isNotEmpty)

        var properties = try TagProperties(url: url)
        properties.customTags["CHAPTER000"] = "00:00:03.000"
        properties.customTags["CHAPTER000NAME"] = "Stale"
        properties.customTags["CHAPTER009"] = "00:00:04.000"
        try properties.save(to: url)

        #expect(chapterSummary(in: url) == before)
    }

    @Test func copyTagsLeavesNoChapterFrames() throws {
        let source = TestBundleResources.shared.tabla_flac
        try #require(chapters(in: source).isNotEmpty)
        let sourceTitle = try #require(try TagProperties(url: source)[.title])

        let destination = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try TagProperties.copyTags(from: source, to: destination)

        let copied = try TagProperties(url: destination)
        #expect(copied[.title] == sourceTitle)
        #expect(copied.customTags.keys.filter { $0.uppercased().hasPrefix("CHAPTER") }.isEmpty)
    }
}
