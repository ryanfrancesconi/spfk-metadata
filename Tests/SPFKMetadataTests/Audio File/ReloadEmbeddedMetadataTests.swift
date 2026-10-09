// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

/// A reload picks up what another writer changed in the file's tags, BEXT and iXML, and nothing
/// else.
@Suite(.tags(.file))
final class ReloadEmbeddedMetadataTests: BinTestCase {
    @Test func aWaveReloadReadsTagsBEXTAndIXMLWrittenElsewhere() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        var description = try await MetaAudioFileDescription(parsing: url)
        let markers = description.markerCollection
        let audioFormat = description.audioFormat

        var writer = try await MetaAudioFileDescription(parsing: url)
        writer.set(tag: .title, value: "Reloaded Title")
        writer.bextDescription?.sequenceDescription = "Reloaded description"
        var ixml = IXMLMetadata()
        ixml.scene = "Reloaded Scene"
        writer.iXMLMetadata = ixml.xml
        try writer.save(dirtyFlags: [.tags])

        try description.reloadEmbeddedMetadata()

        #expect(description.tag(for: .title) == "Reloaded Title")
        #expect(description.bextDescription?.sequenceDescription == "Reloaded description")
        #expect(try IXMLMetadata(xml: try #require(description.iXMLMetadata)).scene == "Reloaded Scene")
        #expect(description.markerCollection == markers)
        #expect(description.audioFormat == audioFormat)
    }

    @Test func aFLACReloadReadsTagsBEXTAndIXMLWrittenElsewhere() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        var description = try await MetaAudioFileDescription(parsing: url)
        let markers = description.markerCollection
        let audioFormat = description.audioFormat
        try #require(description.bextDescription == nil)

        var writer = try await MetaAudioFileDescription(parsing: url)
        writer.set(tag: .title, value: "Reloaded Title")
        var bext = BEXTDescription()
        bext.sequenceDescription = "Reloaded description"
        bext.originator = "Reload"
        writer.bextDescription = bext
        var ixml = IXMLMetadata()
        ixml.scene = "Reloaded Scene"
        writer.iXMLMetadata = ixml.xml
        try writer.save(dirtyFlags: [.tags])

        try description.reloadEmbeddedMetadata()

        #expect(description.tag(for: .title) == "Reloaded Title")
        #expect(description.bextDescription?.sequenceDescription == "Reloaded description")
        #expect(try IXMLMetadata(xml: try #require(description.iXMLMetadata)).scene == "Reloaded Scene")
        #expect(description.markerCollection == markers)
        #expect(description.audioFormat == audioFormat)
    }

    /// A reload clears what the file no longer holds rather than keeping the previous value.
    @Test func aFLACReloadDropsBEXTAndIXMLRemovedElsewhere() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        var writer = try await MetaAudioFileDescription(parsing: url)
        var bext = BEXTDescription()
        bext.sequenceDescription = "To be removed"
        writer.bextDescription = bext
        var ixml = IXMLMetadata()
        ixml.scene = "To be removed"
        writer.iXMLMetadata = ixml.xml
        try writer.save(dirtyFlags: [.tags])

        var description = try await MetaAudioFileDescription(parsing: url)
        try #require(description.bextDescription != nil)

        writer.bextDescription = nil
        writer.iXMLMetadata = nil
        try writer.save(dirtyFlags: [.tags])

        try description.reloadEmbeddedMetadata()

        #expect(description.bextDescription == nil)
        #expect(description.iXMLMetadata == nil)
    }

    @Test func aTagRemovedElsewhereIsGoneAfterAReload() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        var writer = try await MetaAudioFileDescription(parsing: url)
        writer.set(tag: .album, value: "To Be Removed")
        try writer.save(dirtyFlags: [.tags])

        var description = try await MetaAudioFileDescription(parsing: url)
        try #require(description.tag(for: .album) == "To Be Removed")

        writer.tagProperties.set(tag: .album, value: nil)
        try writer.save(dirtyFlags: [.tags])

        try description.reloadEmbeddedMetadata()

        #expect(description.tag(for: .album) == nil)
    }
}
