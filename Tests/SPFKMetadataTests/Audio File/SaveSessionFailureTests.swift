// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreGraphics
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A component that fails a non-WAV save is reported by name, after every other component is
/// written.
@Suite(.tags(.file))
final class SaveSessionFailureTests: BinTestCase {
    enum Format: String, CaseIterable, CustomTestStringConvertible {
        case mp3, flac, ogg, opus, m4a, aiff

        var testDescription: String { rawValue }

        var fixture: URL {
            switch self {
            case .mp3: TestBundleResources.shared.tabla_mp3
            case .flac: TestBundleResources.shared.tabla_flac
            case .ogg: TestBundleResources.shared.tabla_ogg
            case .opus: TestBundleResources.shared.sine_opus
            case .m4a: TestBundleResources.shared.tabla_m4a
            case .aiff: TestBundleResources.shared.tabla_aif
            }
        }
    }

    private static let editedTitle = "Session Edited"

    @Test(arguments: Format.allCases)
    func artworkEncodeFailureWritesTheRest(format: Format) async throws {
        let url = try copyToBin(url: format.fixture)
        var description = try await MetaAudioFileDescription(parsing: url)

        // Wider than JPEG can store, and JPEG is where an untyped image is encoded.
        let context = try #require(CGContext(
            data: nil, width: 70000, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        description.imageDescription.cgImage = context.makeImage()
        description.tagProperties[.title] = Self.editedTitle
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "First", startTime: 0.5),
            AudioMarkerDescription(name: "Second", startTime: 1.5),
        ])

        #expect(throws: MetadataError.incompleteSave(
            written: Set(MetadataDirtyFlag.tags.components + [.markers]), failures: [.writeFailed(.artwork, url)]
        )) {
            try description.save(dirtyFlags: [.tags, .image, .markers])
        }

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == Self.editedTitle)
        #expect(reread.markerCollection.markerDescriptions.map(\.name) == ["First", "Second"])
    }

    /// A file that cannot be opened for writing names no component: nothing in it was written, a
    /// markers save included.
    @Test func aFileThatCannotBeOpenedFailsTheWholeSave() throws {
        let url = bin.appendingPathComponent("unreadable.m4a")
        try Data(repeating: 0x5A, count: 4096).write(to: url)

        var description = MetaAudioFileDescription(url: url, fileType: .m4a)

        #expect(throws: MetadataError.saveFailed(url)) {
            try description.save(dirtyFlags: [.markers])
        }
    }
}
