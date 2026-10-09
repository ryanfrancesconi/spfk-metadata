// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// Artwork whose read failed is never written back as "no artwork".
@Suite(.tags(.file))
final class ArtworkReadFailureSaveTests: BinTestCase {
    static let formats: [URL] = {
        let resources = TestBundleResources.shared
        return [resources.tabla_mp3, resources.tabla_flac, resources.tabla_m4a, resources.tabla_aif, resources.tabla_ogg]
    }()

    static let failingArtwork = MetaAudioFileDescription.ParseReads(artwork: { throw MetadataError.readFailed(.artwork, $0) })

    /// A copy holding the artwork of `mp3_id3`, and the bytes it stores.
    private func prepared(_ source: URL) throws -> (URL, Data) {
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)

        let picture = try #require(try TagPictureRef.reading(url: TestBundleResources.shared.mp3_id3))
        #expect(TagPicture.write(picture, path: url.path))

        let stored = try #require(try TagPictureRef.reading(url: url)?.storedData)
        return (url, stored)
    }

    @Test(arguments: formats)
    func anArtworkSaveAfterAFailedArtworkReadThrowsAndLeavesTheArtwork(source: URL) async throws {
        let (url, stored) = try prepared(source)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingArtwork)
        #expect(description.readStatus.failed == [.artwork])
        #expect(description.artwork.pictureRef == nil)

        #expect(throws: MetadataError.incompleteSave(written: [], failures: [.readFailed(.artwork, url)])) {
            try description.save(dirtyFlags: [.artwork])
        }

        #expect(try TagPictureRef.reading(url: url)?.storedData == stored)
    }

    /// The tags are written; the artwork that shares the save is left as the file has it.
    @Test(arguments: formats)
    func aTagAndArtworkSaveAfterAFailedArtworkReadWritesOnlyTheTags(source: URL) async throws {
        let (url, stored) = try prepared(source)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingArtwork)
        description.set(tag: .title, value: "Edited")

        #expect(throws: MetadataError.incompleteSave(
            written: Set(MetadataDirtyFlag.tags.components),
            failures: [.readFailed(.artwork, url)]
        )) {
            try description.save(dirtyFlags: [.tags, .artwork])
        }

        let onDisk = try await MetaAudioFileDescription(parsing: url)
        #expect(onDisk.tag(for: .title) == "Edited")
        #expect(try TagPictureRef.reading(url: url)?.storedData == stored)
    }

    @Test func aFileWithoutArtworkReadsAsAbsent() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.mp3_no_metadata)
        #expect(description.readStatus.failed.isEmpty)
        #expect(description.artwork.pictureRef == nil)
    }
}
