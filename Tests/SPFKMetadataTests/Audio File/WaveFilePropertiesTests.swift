// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
final class WaveFilePropertiesTests: BinTestCase {
    @Test(arguments: [
        TestBundleResources.shared.tabla_wav,
        TestBundleResources.shared.wav_bext_v1,
        TestBundleResources.shared.cowbell_bext_wav,
    ])
    func matchesTheParse(url: URL) async throws {
        let properties = try #require(WaveFileProperties(url: url))
        let parsed = try await MetaAudioFileDescription(parsing: url)

        #expect(properties.audioFormat == parsed.audioFormat)
        #expect(properties.bextDescription == parsed.bextDescription)
    }

    /// TagLib opens a `.wav` of arbitrary bytes and reports a format of zeros, as the parse does.
    @Test func fileWithNoFormatReportsZeros() async throws {
        deleteBinOnExit = true
        let url = bin.appendingPathComponent("not-a-wave.wav")
        try Data(repeating: 0x2A, count: 64).write(to: url)

        let properties = try #require(WaveFileProperties(url: url))
        #expect(properties.audioFormat.sampleRate == 0)
        #expect(properties.audioFormat.channelCount == 0)
        #expect(properties.bextDescription == nil)
        #expect(try await properties.audioFormat == MetaAudioFileDescription(parsing: url).audioFormat)
    }

    @Test func missingFileIsNil() {
        #expect(WaveFileProperties(url: bin.appendingPathComponent("missing.wav")) == nil)
    }
}
