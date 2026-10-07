// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
final class ProductionChunksTests: BinTestCase {
    static let bextSources = [TestBundleResources.shared.cowbell_bext_wav, TestBundleResources.shared.flac_bext_ixml_external]
    static let ixmlSources = [TestBundleResources.shared.ixml_chunk, TestBundleResources.shared.flac_bext_ixml_external]
    static let destinations = [TestBundleResources.shared.tabla_wav, TestBundleResources.shared.tabla_flac]

    private func copy(_ source: URL) throws -> URL {
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private func fileType(_ url: URL) throws -> AudioFileType {
        try #require(AudioFileType(url: url))
    }

    @Test(arguments: bextSources, destinations)
    func bextRoundTrips(source: URL, destination: URL) throws {
        let bext = try #require(ProductionChunks.readBEXT(from: source, fileType: fileType(source)))
        let url = try copy(destination)

        #expect(ProductionChunks.readBEXT(from: url, fileType: try fileType(url)) == nil)

        try ProductionChunks.writeBEXT(bext, to: url, fileType: fileType(url))

        let readBack = try #require(ProductionChunks.readBEXT(from: url, fileType: fileType(url)))

        // `sampleRate` is the host file's, not a chunk field.
        #expect(try readBack.sampleRate == TagProperties(url: url).audioProperties?.sampleRate)

        var expected = bext
        expected.sampleRate = readBack.sampleRate
        #expect(readBack == expected)
    }

    @Test(arguments: ixmlSources, destinations)
    func ixmlRoundTrips(source: URL, destination: URL) throws {
        let xml = try #require(ProductionChunks.readIXML(from: source, fileType: fileType(source)))
        let url = try copy(destination)

        #expect(ProductionChunks.readIXML(from: url, fileType: try fileType(url)) == nil)

        try ProductionChunks.writeIXML(xml, to: url, fileType: fileType(url))

        #expect(ProductionChunks.readIXML(from: url, fileType: try fileType(url)) == xml)
    }

    @Test(arguments: [TestBundleResources.shared.cowbell_bext_wav, TestBundleResources.shared.ixml_chunk, TestBundleResources.shared.flac_bext_ixml_external])
    func removeAllClearsBothAndKeepsTags(source: URL) throws {
        let url = try copy(source)
        let type = try fileType(url)
        let tagsBefore = try TagProperties(url: url)

        #expect(
            ProductionChunks.readBEXT(from: url, fileType: type) != nil
                || ProductionChunks.readIXML(from: url, fileType: type) != nil
        )

        try ProductionChunks.removeAll(from: url, fileType: type)

        #expect(ProductionChunks.readBEXT(from: url, fileType: type) == nil)
        #expect(ProductionChunks.readIXML(from: url, fileType: type) == nil)
        #expect(try TagProperties(url: url).data == tagsBefore.data)
    }

    @Test func removeAllLeavesAFileWithNeitherUnwritten() throws {
        let url = try copy(TestBundleResources.shared.tabla_wav)
        let before = try Data(contentsOf: url)

        try ProductionChunks.removeAll(from: url, fileType: .wav)

        #expect(try Data(contentsOf: url) == before)
    }

    @Test func otherTypesAreUnsupported() throws {
        let url = try copy(TestBundleResources.shared.tabla_mp3)
        let bext = try #require(ProductionChunks.readBEXT(from: TestBundleResources.shared.cowbell_bext_wav, fileType: .wav))

        #expect(ProductionChunks.readBEXT(from: url, fileType: .mp3) == nil)
        #expect(ProductionChunks.readIXML(from: url, fileType: .mp3) == nil)

        #expect(throws: MetadataError.unsupportedFormat(.mp3, .bext)) {
            try ProductionChunks.writeBEXT(bext, to: url, fileType: .mp3)
        }
        #expect(throws: MetadataError.unsupportedFormat(.mp3, .ixml)) {
            try ProductionChunks.writeIXML("<BWFXML/>", to: url, fileType: .mp3)
        }
        #expect(throws: MetadataError.unsupportedFormat(.mp3, .bext)) {
            try ProductionChunks.removeAll(from: url, fileType: .mp3)
        }
    }

    @Test(arguments: [AudioFileType.wav, .flac])
    func missingFileThrows(type: AudioFileType) throws {
        let url = bin.appendingPathComponent("missing.\(type.pathExtension)")
        let bext = try #require(ProductionChunks.readBEXT(from: TestBundleResources.shared.cowbell_bext_wav, fileType: .wav))

        #expect(throws: MetadataError.writeFailed(.bext, url)) {
            try ProductionChunks.writeBEXT(bext, to: url, fileType: type)
        }
        #expect(throws: MetadataError.writeFailed(.ixml, url)) {
            try ProductionChunks.writeIXML("<BWFXML/>", to: url, fileType: type)
        }
        #expect(throws: MetadataError.removeFailed(.bext, url)) {
            try ProductionChunks.removeAll(from: url, fileType: type)
        }
    }
}
