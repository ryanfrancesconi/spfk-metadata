// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// Regression tests for UTF-8 encoding in the TagLib C bridge.
/// TagLib's String(const char*) and toCString() both default to Latin-1;
/// these tests verify non-ASCII tags survive a complete save/load round-trip
/// across all supported formats via the TagFile property map path.
@Suite
class UTF8EncodingTests: BinTestCase {
    private static let title = "für — Ångström • naïve"
    private static let artist = "Björk / Sigur Rós"
    private static let comment = "Ñoño: café résumé"

    @Test(.tags(.file), arguments: [
        TestBundleResources.shared.tabla_flac,
        TestBundleResources.shared.tabla_mp3,
        TestBundleResources.shared.tabla_ogg,
        TestBundleResources.shared.tabla_m4a,
        TestBundleResources.shared.tabla_wav,
    ])
    func nonASCIIRoundTrip(url: URL) async throws {
        let tmpfile = try copyToBin(url: url)

        var props = TagProperties()
        props[.title] = Self.title
        props[.artist] = Self.artist
        props[.comment] = Self.comment
        try props.save(to: tmpfile)

        let loaded = try TagProperties(url: tmpfile)
        #expect(loaded[.title] == Self.title)
        #expect(loaded[.artist] == Self.artist)
        #expect(loaded[.comment] == Self.comment)
    }
}
