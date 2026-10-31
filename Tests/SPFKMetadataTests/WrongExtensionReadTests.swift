// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A file whose content is another format than its extension names is read as what it is.
@Suite(.tags(.file))
final class WrongExtensionReadTests: BinTestCase {
    private func renamed(_ url: URL, to pathExtension: String) throws -> URL {
        let copy = bin.appendingPathComponent("renamed-\(UUID().uuidString).\(pathExtension)")
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }

    private func write(_ data: Data, as pathExtension: String) throws -> URL {
        let url = bin.appendingPathComponent("header-\(UUID().uuidString).\(pathExtension)")
        try data.write(to: url)
        return url
    }

    @Test(arguments: [
        (TestBundleResources.shared.tabla_m4a, "mp3", AudioFileType.m4a),
        (TestBundleResources.shared.tabla_wav, "mp3", AudioFileType.wav),
        (TestBundleResources.shared.tabla_flac, "mp3", AudioFileType.flac),
        (TestBundleResources.shared.tabla_aif, "wav", AudioFileType.aiff),
    ])
    func aParseReadsTheContent(source: URL, named: String, expected: AudioFileType) async throws {
        let asNamed = try await MetaAudioFileDescription(parsing: try copyToBin(url: source))
        try #require(asNamed.tagProperties.tags.isNotEmpty)

        let misnamed = try await MetaAudioFileDescription(parsing: try renamed(source, to: named))

        #expect(misnamed.fileType == expected)
        #expect(misnamed.tagProperties.tags == asNamed.tagProperties.tags)
        #expect(misnamed.markerCollection.count == asNamed.markerCollection.count)
    }

    /// AVFoundation types a file by its extension, and under `.mp3` refuses other containers.
    @Test(arguments: [
        (TestBundleResources.shared.tabla_wav, "mp3", false),
        (TestBundleResources.shared.tabla_m4a, "mp3", false),
        (TestBundleResources.shared.tabla_aif, "wav", true),
        (TestBundleResources.shared.tabla_m4a, "wav", true),
    ])
    func playabilityIsWhatAVFoundationOpens(source: URL, named: String, expected: Bool) async throws {
        let description = try await MetaAudioFileDescription(parsing: try renamed(source, to: named))

        #expect(description.isAVPlayable == expected)
    }

    @Test func anID3v2TagBeforeTheContainerIsSkipped() throws {
        // Version 4, no flags, a synchsafe size of 16, then 16 bytes of padding.
        let tag = Data([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10]) + Data(count: 16)
        let flac = try Data(contentsOf: TestBundleResources.shared.tabla_flac)

        #expect(AudioFileType(url: try write(tag + flac, as: "mp3")) == .flac)
    }

    /// A WAVE holding MPEG audio is MP3 to TagLib when named so, and a WAVE under any other name.
    @Test(arguments: [("mp3", AudioFileType.mp3), ("m4a", AudioFileType.wav), ("wav", AudioFileType.wav)])
    func aWaveHoldingMPEGAudio(named: String, expected: AudioFileType) throws {
        var header = Data("RIFF".utf8) + Data([0x00, 0x10, 0x00, 0x00]) + Data("WAVEfmt ".utf8)
        header += Data([0x1E, 0x00, 0x00, 0x00, 0x55, 0x00, 0x02, 0x00]) + Data(count: 32)

        #expect(AudioFileType(url: try write(header, as: named)) == expected)
    }

    @Test func aFileThatCannotBeReadIsTypedByItsExtension() {
        #expect(AudioFileType(url: bin.appendingPathComponent("missing-\(UUID().uuidString).m4a")) == .m4a)
    }
}
