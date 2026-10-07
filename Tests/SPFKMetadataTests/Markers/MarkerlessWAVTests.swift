// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// The bridge reports a WAV without markers as nil rather than an empty array.
@Suite(.tags(.file))
final class MarkerlessWAVTests: BinTestCase {
    @Test func parsesToAnEmptyCollection() async throws {
        let url = TestBundleResources.shared.cowbell_wav
        let waveFile = WaveFileC(path: url.path)
        try #require(waveFile.load())
        try #require(waveFile.markers == nil)

        #expect(try await MetaAudioFileDescription(parsing: url).markerCollection.count == 0)
    }

    @Test func savingAnEmptyMarkerSetSucceeds() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_wav)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [.markers])

        #expect(try await MetaAudioFileDescription(parsing: url).markerCollection.count == 0)
    }
}
