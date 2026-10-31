// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing
import UniformTypeIdentifiers

@testable import SPFKMetadata

/// A file whose content is another format than its extension names is not saved: the wrong format's
/// metadata at its start leaves an `.m4a` or AIFF unplayable.
@Suite(.tags(.file))
final class WrongExtensionSaveTests: BinTestCase {
    private func renamed(_ url: URL, to pathExtension: String) throws -> URL {
        let copy = bin.appendingPathComponent("renamed-\(UUID().uuidString).\(pathExtension)")
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }

    @Test(arguments: [
        (TestBundleResources.shared.tabla_m4a, "mp3", UTType.mpeg4Audio, "m4a"),
        (TestBundleResources.shared.tabla_aif, "mp3", UTType.aiff, "aif"),
        (TestBundleResources.shared.tabla_m4a, "wav", UTType.mpeg4Audio, "m4a"),
    ])
    func aSaveIsRefusedAndLeavesTheFileAsItWas(
        source: URL, named: String, actual: UTType, expectedExtension: String
    ) async throws {
        let url = try renamed(source, to: named)
        let original = try Data(contentsOf: url)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "After"

        #expect(throws: MetadataError.contentMismatch(url, actual: actual, pathExtension: expectedExtension)) {
            try description.save(dirtyFlags: [.tags])
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func aFileNamedForItsContentStillSaves() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "After"
        try description.save(dirtyFlags: [.tags])

        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "After")
    }
}
