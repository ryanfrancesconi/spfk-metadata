// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Emptying a component in the description and saving removes it from the file, leaving every
/// other component as it was.
@Suite(.tags(.file))
final class ClearMetadataSaveTests: BinTestCase {
    /// A description holding a title, a rating, artwork, BEXT and iXML, saved and reparsed.
    private func planted(_ fixture: URL, productionChunks: Bool) async throws -> MetaAudioFileDescription {
        let url = try copyToBin(url: fixture)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Planted Title")
        description.tagProperties[.rating] = "4"
        description.artwork.pictureRef = try SafetyNetSetup.picture(TestBundleResources.shared.songbird)

        if productionChunks {
            var bext = BEXTDescription()
            bext.sequenceDescription = "Planted BEXT"
            description.bextDescription = bext
            var ixml = IXMLMetadata()
            ixml.scene = "Planted Scene"
            description.iXMLMetadata = ixml.xml
        }

        try description.save(dirtyFlags: [.tags, .artwork])

        let parsed = try await MetaAudioFileDescription(parsing: url)
        try #require(parsed.tag(for: .title) == "Planted Title")
        try #require(parsed.tagProperties[.rating] != nil)
        try #require(parsed.artwork.pictureRef != nil)

        if productionChunks {
            try #require(parsed.bextDescription != nil)
            try #require(parsed.iXMLMetadata != nil)
        }

        return parsed
    }

    @Test(arguments: [TestBundleResources.shared.tabla_wav, TestBundleResources.shared.tabla_flac])
    func clearingBEXTKeepsIXML(fixture: URL) async throws {
        deleteBinOnExit = true
        var description = try await planted(fixture, productionChunks: true)

        description.bextDescription = nil
        try description.save(dirtyFlags: [.tags])

        let reloaded = try await MetaAudioFileDescription(parsing: description.url)
        #expect(reloaded.bextDescription == nil)
        #expect(try IXMLMetadata(xml: #require(reloaded.iXMLMetadata)).scene == "Planted Scene")
        #expect(reloaded.tag(for: .title) == "Planted Title")
    }

    @Test(arguments: [TestBundleResources.shared.tabla_wav, TestBundleResources.shared.tabla_flac])
    func clearingIXMLKeepsBEXT(fixture: URL) async throws {
        deleteBinOnExit = true
        var description = try await planted(fixture, productionChunks: true)

        description.iXMLMetadata = nil
        try description.save(dirtyFlags: [.tags])

        let reloaded = try await MetaAudioFileDescription(parsing: description.url)
        #expect(reloaded.iXMLMetadata == nil)
        #expect(reloaded.bextDescription?.sequenceDescription == "Planted BEXT")
    }

    @Test(arguments: [
        TestBundleResources.shared.tabla_wav,
        TestBundleResources.shared.tabla_flac,
        TestBundleResources.shared.tabla_mp3,
        TestBundleResources.shared.tabla_m4a,
        TestBundleResources.shared.tabla_ogg,
        TestBundleResources.shared.tabla_aif,
    ])
    func clearingTagsRemovesTagsAndRatingAndKeepsArtwork(fixture: URL) async throws {
        deleteBinOnExit = true
        let isProduction = fixture == TestBundleResources.shared.tabla_wav || fixture == TestBundleResources.shared.tabla_flac
        var description = try await planted(fixture, productionChunks: isProduction)

        description.tagProperties.removeAll()
        try description.save(dirtyFlags: [.tags])

        let reloaded = try await MetaAudioFileDescription(parsing: description.url)
        #expect(reloaded.tagProperties.tags.isEmpty, "\(reloaded.tagProperties.tags)")
        #expect(reloaded.tagProperties.customTags.isEmpty, "\(reloaded.tagProperties.customTags)")
        #expect(reloaded.artwork.pictureRef != nil)

        if isProduction {
            #expect(reloaded.bextDescription != nil)
            #expect(reloaded.iXMLMetadata != nil)
        }
    }

    @Test func clearingINFOFieldsEmptiesTheINFOChunk() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        var description = try await MetaAudioFileDescription(parsing: url)
        var fields = description.riffInfoFields ?? RIFFInfoFields()
        fields.set(field: "ISRF", value: "Planted Source")
        description.riffInfoFields = fields
        description.set(tag: .title, value: "Planted Title")
        try description.save(dirtyFlags: [.tags])

        var parsed = try await MetaAudioFileDescription(parsing: url)
        try #require(parsed.riffInfoFields?.fields["ISRF"] == "Planted Source")

        parsed.riffInfoFields = RIFFInfoFields()
        try parsed.save(dirtyFlags: [.tags])

        let reloaded = try await MetaAudioFileDescription(parsing: url)
        #expect(reloaded.riffInfoFields?.fields.isEmpty ?? true, "\(reloaded.riffInfoFields?.fields ?? [:])")
        #expect(reloaded.tag(for: .title) == "Planted Title")
    }
}
