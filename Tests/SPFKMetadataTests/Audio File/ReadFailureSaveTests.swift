// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A component whose read failed is never written back as the empty default it was left with.
@Suite(.tags(.file))
final class ReadFailureSaveTests: BinTestCase {
    static let formats: [URL] = {
        let resources = TestBundleResources.shared
        return [resources.tabla_mp3, resources.tabla_flac, resources.tabla_m4a, resources.tabla_aif, resources.tabla_ogg]
    }()

    static let failingTags = MetaAudioFileDescription.ParseReads(tags: { throw MetadataError.readFailed(.tags, $0) })
    static let failingMarkers = MetaAudioFileDescription.ParseReads(markers: { url, _ in throw MetadataError.readFailed(.markers, url) })
    static let failingFLACChunks = MetaAudioFileDescription.ParseReads(flacChunks: { _ in false })

    /// A copy holding a title, an artist and two markers, written through an ordinary save.
    private func prepared(_ source: URL) async throws -> URL {
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Kept Title")
        description.set(tag: .artist, value: "Kept Artist")
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "One", startTime: 0.5, markerID: 0),
            AudioMarkerDescription(name: "Two", startTime: 1.0, markerID: 1),
        ])
        try description.save(dirtyFlags: [.tags, .markers])

        return url
    }

    private func expectKept(_ url: URL) async throws {
        let onDisk = try await MetaAudioFileDescription(parsing: url)
        #expect(onDisk.tag(for: .title) == "Kept Title")
        #expect(onDisk.tag(for: .artist) == "Kept Artist")
        #expect(onDisk.markerCollection.markerDescriptions.compactMap(\.name) == ["One", "Two"])
    }

    @Test(arguments: formats)
    func aTagSaveAfterAFailedTagReadThrowsAndLeavesTheFile(source: URL) async throws {
        let url = try await prepared(source)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingTags)
        #expect(description.readStatus.failed == [.tags])
        #expect(description.tag(for: .title) == nil)

        description.set(tag: .title, value: "Edited")

        // A FLAC holds its own BEXT and iXML, which were read and so are written.
        let written: Set<MetadataComponent> = source.pathExtension == "flac" ? [.bext, .ixml] : []

        #expect(throws: MetadataError.incompleteSave(written: written, failures: [.readFailed(.tags, url)])) {
            try description.save(dirtyFlags: [.tags])
        }

        try await expectKept(url)
    }

    /// Every container save outside WAV writes the whole tag map, so a markers-only save reaches
    /// the tags too.
    @Test(arguments: formats)
    func aMarkerSaveAfterAFailedTagReadKeepsTheFileTags(source: URL) async throws {
        let url = try await prepared(source)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingTags)
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "One", startTime: 0.5, markerID: 0),
            AudioMarkerDescription(name: "Two", startTime: 1.0, markerID: 1),
            AudioMarkerDescription(name: "Three", startTime: 1.5, markerID: 2),
        ])

        try description.save(dirtyFlags: [.markers])

        let onDisk = try await MetaAudioFileDescription(parsing: url)
        #expect(onDisk.tag(for: .title) == "Kept Title")
        #expect(onDisk.tag(for: .artist) == "Kept Artist")
        #expect(onDisk.markerCollection.markerDescriptions.compactMap(\.name) == ["One", "Two", "Three"])
    }

    @Test(arguments: formats)
    func aMarkerSaveAfterAFailedMarkerReadThrowsAndLeavesTheFile(source: URL) async throws {
        let url = try await prepared(source)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingMarkers)
        #expect(description.readStatus.failed == [.markers])
        #expect(description.markerCollection.count == 0)

        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "New", startTime: 0.25, markerID: 0),
        ])

        #expect(throws: MetadataError.incompleteSave(written: [], failures: [.readFailed(.markers, url)])) {
            try description.save(dirtyFlags: [.markers])
        }

        try await expectKept(url)
    }

    /// The component that was read is written; the one that was not is named after it.
    @Test(arguments: formats)
    func aSaveWritesTheComponentsThatWereRead(source: URL) async throws {
        let url = try await prepared(source)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingMarkers)
        description.set(tag: .title, value: "Edited")
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "New", startTime: 0.25, markerID: 0),
        ])

        #expect(throws: MetadataError.incompleteSave(
            written: Set(MetadataDirtyFlag.tags.components), failures: [.readFailed(.markers, url)]
        )) {
            try description.save(dirtyFlags: [.tags, .markers])
        }

        let onDisk = try await MetaAudioFileDescription(parsing: url)
        #expect(onDisk.tag(for: .title) == "Edited")
        #expect(onDisk.markerCollection.markerDescriptions.compactMap(\.name) == ["One", "Two"])
    }

    /// The chunks are refused on their own: the title edit that shares their flag is written.
    @Test func aFLACWhoseChunksFailedToReadKeepsItsBEXTAndIXMLAndSavesItsTags() async throws {
        let source = TestBundleResources.shared.flac_bext_ixml_external
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)

        let original = try await MetaAudioFileDescription(parsing: url)
        #expect(original.bextDescription != nil)
        #expect(original.iXMLMetadata != nil)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingFLACChunks)
        #expect(description.readStatus.failed == [.bext, .ixml])
        #expect(description.bextDescription == nil)

        description.set(tag: .title, value: "Edited")

        #expect(throws: MetadataError.incompleteSave(
            written: [.tags, .rating], failures: [.readFailed(.bext, url), .readFailed(.ixml, url)]
        )) {
            try description.save(dirtyFlags: [.tags])
        }

        let onDisk = try await MetaAudioFileDescription(parsing: url)
        #expect(onDisk.tag(for: .title) == "Edited")
        #expect(onDisk.bextDescription == original.bextDescription)
        #expect(onDisk.iXMLMetadata == original.iXMLMetadata)
    }

    @Test func aReloadThatReadsTheTagsAllowsTheirSave() async throws {
        let url = try await prepared(TestBundleResources.shared.tabla_mp3)

        var description = try await MetaAudioFileDescription(parsing: url, reads: Self.failingTags)
        try description.reloadEmbeddedMetadata()

        #expect(description.readStatus.failed.isEmpty)
        #expect(description.tag(for: .title) == "Kept Title")

        description.set(tag: .title, value: "Edited")
        try description.save(dirtyFlags: [.tags])

        let onDisk = try await MetaAudioFileDescription(parsing: url)
        #expect(onDisk.tag(for: .title) == "Edited")
        #expect(onDisk.tag(for: .artist) == "Kept Artist")
    }

    /// The guard reads the status, not the format, so a WAV is held to it too.
    @Test func aWAVTagSaveIsRefusedWhenItsTagsWereNotRead() async throws {
        let url = try await prepared(TestBundleResources.shared.tabla_wav)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.readStatus.failed = [.tags]
        description.tagProperties = TagProperties()

        #expect(throws: MetadataError.incompleteSave(written: [.bext, .ixml], failures: [.readFailed(.tags, url)])) {
            try description.save(dirtyFlags: [.tags])
        }

        try await expectKept(url)
    }

    // MARK: - Absent is not failed

    @Test(arguments: formats)
    func aFileWithoutMarkersReadsAsEmpty(source: URL) async throws {
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)
        let fileType = try #require(AudioFileType(url: url))
        try EmbeddedMarkers.removeAll(from: url, fileType: fileType)

        let markers = try await AudioMarkerDescriptionCollection(url: url)
        #expect(markers.count == 0)

        let description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.readStatus.failed.isEmpty)
    }

    @Test(arguments: formats)
    func aMarkerReadOfAFileThatCannotBeOpenedThrows(source: URL) async throws {
        let missing = bin.appendingPathComponent("missing").appendingPathExtension(source.pathExtension)

        await #expect(throws: MetadataError.readFailed(.markers, missing)) {
            _ = try await AudioMarkerDescriptionCollection(url: missing)
        }
    }
}
