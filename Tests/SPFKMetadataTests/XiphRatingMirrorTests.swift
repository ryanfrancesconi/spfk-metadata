// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A Xiph file's `FMPS_RATING` is the rating's own mirror: not a tag to show, edit or copy.
@Suite(.tags(.file))
final class XiphRatingMirrorTests: BinTestCase {
    private func ratedFLAC() async throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.rating] = "4"
        try description.save(dirtyFlags: [.metadata])
        return url
    }

    @Test func theRatingMirrorIsNotReadAsATag() async throws {
        let url = try await ratedFLAC()

        let tags = try TagProperties(url: url)

        #expect(tags[.rating] == "4")
        #expect(tags.customTags.keys.contains { $0.uppercased() == "FMPS_RATING" } == false)
    }

    @Test func copyingTagsCarriesTheRatingButNotItsMirror() async throws {
        let source = try await ratedFLAC()
        let destination = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        try TagProperties.copyTags(from: source, to: destination)

        let frames = try #require(try ID3v2Frames.tag(in: destination)).frames
        #expect(frames.contains { $0.id == "TXXX" && String(decoding: $0.body, as: UTF8.self).contains("FMPS_RATING") } == false)
        #expect(try TagProperties(url: destination)[.rating] == "4")
    }
}
