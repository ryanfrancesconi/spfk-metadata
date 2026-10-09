// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite
struct ImageDescriptionReadTests {
    /// The bytes a parse holds, so a write of either puts the file's own picture back.
    @Test(arguments: [TestBundleResources.shared.mp3_id3, TestBundleResources.shared.wav_bext_v2])
    func readHoldsTheBytesAParseHolds(url: URL) async throws {
        let parsed = try await MetaAudioFileDescription(parsing: url).imageDescription
        let read = try #require(try ImageDescription.read(from: url))

        let stored = try #require(read.storedPicture)
        #expect(stored == parsed.storedPicture)
        #expect(read.cgImage?.width == parsed.cgImage?.width)
    }

    @Test(arguments: [TestBundleResources.shared.mp3_no_metadata, TestBundleResources.shared.toc_many_children])
    func readIsNilWithoutArtwork(url: URL) throws {
        #expect(try ImageDescription.read(from: url) == nil)
    }
}
