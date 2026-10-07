// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Each public entry point reports its failure as a `MetadataError` naming the component.
@Suite(.tags(.file))
final class MetadataErrorSiteTests: BinTestCase {
    private var missing: URL { bin.appendingPathComponent("missing.mp3") }

    private func readOnlyCopy(_ source: URL) throws -> URL {
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        return url
    }

    private func restoreWritable(_ url: URL) {
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    }

    // MARK: - Tags

    @Test func tagReadOfMissingFile() {
        #expect(throws: MetadataError.readFailed(.tags, missing)) {
            try TagProperties(url: missing)
        }
    }

    @Test func tagReadMessageIsUnchanged() {
        let error = #expect(throws: MetadataError.self) { try TagProperties(url: missing) }
        #expect(error?.localizedDescription == "Failed to load tag file: \(missing.path)")
    }

    @Test func tagWriteToReadOnlyFile() throws {
        let url = try readOnlyCopy(TestBundleResources.shared.tabla_mp3)
        defer { restoreWritable(url) }

        var tags = try TagProperties(url: url)
        tags[.title] = "Read Only"

        #expect(throws: MetadataError.writeFailed(.tags, url)) {
            try tags.save(to: url)
        }
    }

    @Test func tagCopyFromMissingFile() throws {
        let destination = bin.appendingPathComponent("destination.mp3")
        try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_mp3, to: destination)

        #expect(throws: MetadataError.copyFailed(.tags, from: missing, to: destination)) {
            try TagProperties.copyTags(from: missing, to: destination)
        }
    }

    @Test func tagRemovalFromMissingFile() {
        #expect(throws: MetadataError.removeFailed(.tags, missing)) {
            try TagProperties.removeAllTags(in: missing)
        }
    }

    // MARK: - Markers

    @Test func chapterReadOfMissingFile() async {
        await #expect(throws: MetadataError.readFailed(.markers, missing)) {
            try await ChapterParser.parse(url: missing)
        }
    }

    @Test func markerReadOfUnknownType() async {
        let url = bin.appendingPathComponent("file.unknown")

        await #expect(throws: MetadataError.unsupportedFormat(nil, .markers)) {
            try await AudioMarkerDescriptionCollection(url: url)
        }
    }

    @Test func markerReadOfTypeWithoutMarkers() async {
        await #expect(throws: MetadataError.unsupportedFormat(.caf, .markers)) {
            try await AudioMarkerDescriptionCollection(url: TestBundleResources.shared.tabla_caf)
        }
    }

    // MARK: - BEXT and XMP

    @Test func bextWriteToMissingFile() throws {
        let url = bin.appendingPathComponent("missing.wav")
        let bext = try #require(BEXTDescription(url: TestBundleResources.shared.cowbell_bext_wav))

        #expect(throws: MetadataError.writeFailed(.bext, url)) {
            try BEXTDescription.write(bextDescription: bext, to: url)
        }
    }

    @Test func storedXMPPacketWriteToReadOnlyFile() throws {
        let url = try readOnlyCopy(TestBundleResources.shared.tabla_wav)
        defer { restoreWritable(url) }

        #expect(throws: MetadataError.writeFailed(.xmpPacket, url)) {
            try StoredXMPPacketWrite.replace("<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"/>").write(to: url)
        }
    }
}
