// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreGraphics
import Foundation
import SPFKBase
import SPFKImage
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A Matroska tag save that outgrows a `Tags` element ahead of the clusters leaves the clusters
/// where they were, the file parses end to end, and the seek head still finds the tags.
@Suite(.tags(.file))
final class MatroskaLayoutTests: BinTestCase {
    enum Writer: String, CaseIterable, CustomTestStringConvertible {
        case descriptionSave
        /// Also adds the file's first attachment, while the grown `Tags` moves.
        case descriptionSaveWithArtwork
        case tagPropertiesSave

        var testDescription: String { rawValue }
    }

    /// Long enough to outgrow any padding the fixture's `Tags` has.
    private static let longTitle = String(repeating: "Matroska layout ", count: 64)

    @Test(arguments: Writer.allCases)
    func aGrownTagSaveLeavesTheClustersInPlace(writer: Writer) async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mka)
        let before = try MatroskaElements(contentsOf: url)
        let cluster = try #require(before.elements(MatroskaElements.ID.cluster).first)
        let tags = try #require(before.elements(MatroskaElements.ID.tags).first)
        try #require(tags.offset < cluster.offset)

        switch writer {
        case .descriptionSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.longTitle
            try description.save(dirtyFlags: [.tags])
        case .descriptionSaveWithArtwork:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.longTitle
            description.artwork.cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
            try description.save(dirtyFlags: [.tags, .artwork])
        case .tagPropertiesSave:
            var properties = try TagProperties(url: url)
            properties[.title] = Self.longTitle
            try properties.save(to: url)
        }

        let after = try MatroskaElements(contentsOf: url)
        let movedCluster = try #require(after.elements(MatroskaElements.ID.cluster).first)
        #expect(movedCluster.offset == cluster.offset)
        #expect(movedCluster.payload == cluster.payload)

        let tagsEntry = try #require(after.seekEntries.first { $0.id == MatroskaElements.ID.tags })
        let tagsOffset = after.segmentDataOffset + Int(tagsEntry.position)
        #expect(after.elements(MatroskaElements.ID.tags).contains { $0.offset == tagsOffset })

        #expect(try TagProperties(url: url)[.title] == Self.longTitle)

        if writer == .descriptionSaveWithArtwork {
            #expect(after.elements(MatroskaElements.ID.attachments).count == 1)
            #expect(try await MetaAudioFileDescription(parsing: url).artwork.cgImage != nil)
        }
    }
}
