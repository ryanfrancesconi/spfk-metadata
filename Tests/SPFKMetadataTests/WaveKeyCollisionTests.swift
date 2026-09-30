// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A custom tag spelled like a standard one doesn't overwrite the standard value on a WAV save.
@Suite(.tags(.file))
class WaveKeyCollisionTests: BinTestCase {
    @Test(arguments: [TagKey.copyrightURL, .encodedBy])
    func standardTagWinsOverCustomOfSameName(key: TagKey) async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        maf.set(tag: key, value: "https://a.example")
        maf.set(customTag: key.taglibKey, value: "https://b.example")
        try maf.save()

        let reparsed = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reparsed.tag(for: key) == "https://a.example")
    }
}
