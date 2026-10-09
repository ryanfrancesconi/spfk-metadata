// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreGraphics
import Foundation
import SPFKBase
import SPFKFileSystem
import SPFKMetadataBase
import SPFKTesting
import SPFKUtils
import Testing

@testable import SPFKMetadata

/// A save that writes some components and not others says which it wrote, and finishes the file's
/// Finder tags and modification date as a complete save does.
@Suite(.tags(.file))
final class PartialSaveTests: BinTestCase {
    static let formats: [URL] = {
        let resources = TestBundleResources.shared
        return [resources.tabla_mp3, resources.tabla_flac, resources.tabla_m4a, resources.tabla_wav]
    }()

    /// Wider than JPEG can store, and JPEG is where an untyped image is encoded.
    private func unencodableImage() throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 70000, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        return try #require(context.makeImage())
    }

    @Test(arguments: formats)
    func aFailedArtworkWriteReportsTheComponentsWritten(source: URL) async throws {
        let url = try copyToBin(url: source)
        var description = try await MetaAudioFileDescription(parsing: url)

        description.artwork.cgImage = try unencodableImage()
        description.tagProperties[.title] = "Partial"
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "One", startTime: 0.5, markerID: 0),
        ])

        var dirtyFlags: Set<MetadataDirtyFlag> = [.tags, .artwork, .markers]

        #if os(macOS)
            description.urlProperties.finderTags = FinderTagGroup(tags: [FinderTagDescription(label: "Partial")])
            dirtyFlags.insert(.finderTags)
        #endif

        #expect(throws: MetadataError.incompleteSave(
            written: Set(dirtyFlags.subtracting([.artwork]).flatMap(\.components)),
            failures: [.writeFailed(.artwork, url)]
        )) {
            try description.save(dirtyFlags: dirtyFlags)
        }

        let fresh = URL(fileURLWithPath: url.path)
        let reread = try await MetaAudioFileDescription(parsing: fresh)
        #expect(reread.tagProperties[.title] == "Partial")
        #expect(reread.markerCollection.markerDescriptions.map(\.name) == ["One"])

        #if os(macOS)
            #expect(FinderTagGroup(url: fresh).tags.map(\.label) == ["Partial"])
            #expect(description.urlProperties.modificationDate == URLProperties(url: fresh).modificationDate)
        #endif
    }

    /// An unread component and a failed write in the same save are both named.
    @Test func everyFailureOfOneSaveIsNamed() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        var description = try await MetaAudioFileDescription(parsing: url, reads: ReadFailureSaveTests.failingMarkers)

        description.artwork.cgImage = try unencodableImage()
        description.tagProperties[.title] = "Partial"

        #expect(throws: MetadataError.incompleteSave(
            written: Set(MetadataDirtyFlag.tags.components),
            failures: [.readFailed(.markers, url), .writeFailed(.artwork, url)]
        )) {
            try description.save(dirtyFlags: [.tags, .artwork, .markers])
        }

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Partial")
    }
}
