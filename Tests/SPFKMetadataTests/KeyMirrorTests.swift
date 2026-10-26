// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// A Xiph or APE `KEY` field, as MusicBrainz Picard writes it, is read as the key and kept as its
/// mirror. What reached disk is read with `VorbisComment`, which shares no code with the writer.
@Suite(.tags(.file, .musicalKey))
final class KeyMirrorTests: BinTestCase {
    private func comment(_ url: URL) throws -> VorbisComment {
        let blocks = try FLACBlocks(Data(contentsOf: url)).blocks
        let block = try #require(blocks.first { $0.blockType == .vorbisComment })
        return try VorbisComment(block.payload)
    }

    /// A FLAC whose comment holds exactly `fields`.
    private func flac(_ fields: [(String, String)]) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        try FLACBlockWriter.rewrite(url) { blocks in
            guard let index = blocks.firstIndex(where: { $0.blockType == .vorbisComment }) else {
                throw FLACBlocks.ReadError.malformed("no comment")
            }
            let vendor = try VorbisComment(blocks[index].payload).vendor
            blocks[index] = FLACBlockWriter.vorbisComment(vendor: vendor, fields: fields.map { .init(key: $0.0, value: $0.1) })
        }

        return url
    }

    @Test func aKEYFieldIsReadAsTheKeyAndNotAsACustomTag() throws {
        let properties = try TagProperties(url: TestBundleResources.shared.keyTagVorbisKEY)
        #expect(properties[.initialKey] == "Am")
        #expect(properties.data.customTags.keys.contains { $0.uppercased() == "KEY" } == false)
    }

    @Test func initialKeyWinsWhereBothExist() throws {
        let url = try flac([("INITIALKEY", "8A"), ("KEY", "Dm")])
        #expect(try TagProperties(url: url)[.initialKey] == "8A")
    }

    @Test func anEditedKeyIsWrittenToBothFields() throws {
        let url = try flac([("KEY", "Am"), ("TITLE", "T")])
        var properties = try TagProperties(url: url)
        properties.setInitialKey("c#m", notation: .standard)
        try properties.save(to: url)

        let stored = try comment(url)
        #expect(stored.values("INITIALKEY") == ["C# Minor"])
        #expect(stored.values("KEY") == ["C# Minor"])
    }

    @Test func anUnrelatedSaveKeepsTheMirrorAndAddsTheKey() throws {
        let url = try flac([("KEY", "Am"), ("TITLE", "T")])
        var properties = try TagProperties(url: url)
        properties.set(tag: .title, value: "Retitled")
        try properties.save(to: url)

        let stored = try comment(url)
        #expect(stored.values("INITIALKEY") == ["Am"])
        #expect(stored.values("KEY") == ["Am"])
    }

    @Test func aStaleMirrorFollowsTheKey() throws {
        let url = try flac([("INITIALKEY", "8A"), ("KEY", "Dm")])
        let properties = try TagProperties(url: url)
        try properties.save(to: url)

        #expect(try comment(url).values("KEY") == ["8A"])
    }

    @Test func aFileWithoutAMirrorNeverGainsOne() throws {
        let url = try flac([("INITIALKEY", "Am")])
        var properties = try TagProperties(url: url)
        properties.setInitialKey("Bm", notation: .short)
        try properties.save(to: url)

        let stored = try comment(url)
        #expect(stored.values("INITIALKEY") == ["Bm"])
        #expect(stored.values("KEY").isEmpty)
    }

    @Test func removingTheKeyRemovesItsMirror() throws {
        let url = try flac([("KEY", "Am"), ("TITLE", "T")])
        var properties = try TagProperties(url: url)
        properties.set(tag: .initialKey, value: nil)
        try properties.save(to: url)

        let stored = try comment(url)
        #expect(stored.values("INITIALKEY").isEmpty)
        #expect(stored.values("KEY").isEmpty)
    }

    /// An APE item: the key's text must reach the file twice, once per field.
    @Test func anAPEKEYIsReadAndMirrored() throws {
        let url = try copyToBin(url: TestBundleResources.shared.sine_wv)
        #expect(TagLibBridge.setProperties(url.path, dictionary: ["KEY": "Am"]))
        #expect(try TagProperties(url: url)[.initialKey] == "Am")

        var properties = try TagProperties(url: url)
        properties.setInitialKey("Ebm", notation: .standard)
        try properties.save(to: url)

        let bytes = try Data(contentsOf: url)
        let needle = Data("Eb Minor".utf8)
        var count = 0
        var range = bytes.startIndex ..< bytes.endIndex
        while let found = bytes.range(of: needle, in: range) {
            count += 1
            range = found.upperBound ..< bytes.endIndex
        }
        #expect(count == 2)
        #expect(try TagProperties(url: url)[.initialKey] == "Eb Minor")
    }

    @Test func aCopyIntoAnotherFormatCarriesTheKeyNotTheMirror() throws {
        let destination = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        #expect(TagLibBridge.copyTags(fromPath: TestBundleResources.shared.keyTagVorbisKEY.path, toPath: destination.path))

        let properties = try TagProperties(url: destination)
        #expect(properties[.initialKey] == "Am")
        #expect(properties.data.customTags.keys.contains { $0.uppercased() == "KEY" } == false)
    }

    @Test func aCopyBetweenMirroringFormatsKeepsTheMirror() throws {
        let destination = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        #expect(TagLibBridge.copyTags(fromPath: TestBundleResources.shared.keyTagVorbisKEY.path, toPath: destination.path))

        let stored = try comment(destination)
        #expect(stored.values("INITIALKEY") == ["Am"])
        #expect(stored.values("KEY") == ["Am"])
    }
}
