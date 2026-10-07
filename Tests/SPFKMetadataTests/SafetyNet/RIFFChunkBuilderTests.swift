// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKBase
import SPFKMetadataC
import SPFKTesting
import Testing

/// The RF64 the net's rf64 row is built from: other readers must take it as the same audio.
@Suite(.tags(.file, .metadataSafetyNet))
final class RIFFChunkBuilderTests: BinTestCase {
    @Test func aLongFormConversionKeepsTheAudioReadable() async throws {
        let source = TestBundleResources.shared.tabla_wav
        let url = bin.appendingPathComponent("long-form.wav")
        try FileManager.default.copyItem(at: source, to: url)

        try RIFFChunkBuilder.convertToLongForm(url)

        let riff = try RIFFChunks(contentsOf: url)
        let original = try RIFFChunks(contentsOf: source)
        #expect(riff.form == "RF64")
        #expect(riff.chunks.map(\.id) == ["ds64"] + original.chunks.map(\.id))
        #expect(riff.first("data") == original.first("data"))
        #expect(riff.longFormSizes?.riffSize == UInt64(try Data(contentsOf: url).count - 8))
        #expect(riff.longFormSizes?.sampleCount == 210_900)

        let converted = try AVAudioFile(forReading: url)
        #expect(converted.length == (try AVAudioFile(forReading: source)).length)
        #expect(try SafetyNetSnapshot.decodedPCM(of: url) == SafetyNetSnapshot.decodedPCM(of: source))

        #expect(WaveFileC(path: url.path).load())
    }
}
