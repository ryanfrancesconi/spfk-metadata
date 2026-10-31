// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A file whose content is another format than its extension names saves as what it is, keeping
/// the container intact and every tag it had.
@Suite(.tags(.file))
final class WrongExtensionSaveTests: BinTestCase {
    private func renamed(_ url: URL, to pathExtension: String) throws -> URL {
        let copy = bin.appendingPathComponent("renamed-\(UUID().uuidString).\(pathExtension)")
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }

    @Test(arguments: [
        (TestBundleResources.shared.tabla_m4a, "mp3", "ftyp", 4),
        (TestBundleResources.shared.tabla_wav, "mp3", "RIFF", 0),
        (TestBundleResources.shared.tabla_flac, "mp3", "fLaC", 0),
        (TestBundleResources.shared.tabla_aif, "wav", "FORM", 0),
    ])
    func aSaveKeepsTheContainerAndItsTags(source: URL, named: String, signature: String, offset: Int) async throws {
        let url = try renamed(source, to: named)

        var description = try await MetaAudioFileDescription(parsing: url)
        let tags = description.tagProperties.tags
        try #require(tags.isNotEmpty)

        description.tagProperties[.title] = "After"
        try description.save(dirtyFlags: [.tags])

        var expected = tags
        expected[.title] = "After"

        #expect(try Data(contentsOf: url).dropFirst(offset).prefix(4) == Data(signature.utf8))
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties.tags == expected)
    }

    @Test func markersSavedToAnMP4NamedAsMP3AreItsChapters() async throws {
        let url = try renamed(TestBundleResources.shared.tabla_m4a, to: "mp3")

        var description = try await MetaAudioFileDescription(parsing: url)
        let markers = description.markerCollection.markerDescriptions
        try #require(markers.count > 1)

        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: Array(markers.dropLast()))
        try description.save(dirtyFlags: [.markers])

        let asMP4 = try renamed(url, to: "m4a")
        #expect(try await AudioMarkerDescriptionCollection(url: asMP4).count == markers.count - 1)
    }
}
