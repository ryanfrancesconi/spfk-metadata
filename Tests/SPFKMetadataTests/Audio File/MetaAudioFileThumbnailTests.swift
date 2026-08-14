// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
final class MetaAudioFileThumbnailTests: TestCaseModel {
    /// A parse must not substitute the file's Finder icon for absent artwork. Doing so stores a
    /// per-machine, per-installed-app image as if it came from the file, and leaves a table row's
    /// icon changing whenever a reparse happens to touch it. Display resolves the file-type icon
    /// instead -- see `NSWorkspace.FinderIcon.fileType(for:)`.
    @Test func fileWithoutEmbeddedArtworkGetsNoImage() async throws {
        let url = TestBundleResources.shared.mp3_no_metadata
        let description = try await MetaAudioFileDescription(parsing: url)

        #expect(description.imageDescription.cgImage == nil)
        #expect(description.imageDescription.thumbnailImage == nil)
        #expect(description.imageDescription.thumbnailData == nil)
    }

    @Test func fileWithEmbeddedArtworkStillGetsThumbnail() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let description = try await MetaAudioFileDescription(parsing: url)

        #expect(description.imageDescription.cgImage != nil)

        let thumbnail = try #require(description.imageDescription.thumbnailImage)
        #expect(thumbnail.width <= 64)
        #expect(thumbnail.height <= 64)
    }
}
