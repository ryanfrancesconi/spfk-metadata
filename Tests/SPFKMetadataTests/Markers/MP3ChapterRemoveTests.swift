// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// Removing an MP3's chapters removes the table of contents that lists them.
@Suite(.tags(.file))
final class MP3ChapterRemoveTests: BinTestCase {
    @Test func removeTakesTheTableOfContentsWithTheChapters() throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try #require(try Data(contentsOf: url).range(of: Data("CTOC".utf8)) != nil)

        #expect(MPEGChapterUtil.remove(url.path))

        let data = try Data(contentsOf: url)
        #expect(data.range(of: Data("CHAP".utf8)) == nil)
        #expect(data.range(of: Data("CTOC".utf8)) == nil)
    }
}
