// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// INFO text is decoded with the code page a `CSET` chunk declares, as UTF-8 when there is none,
/// and is always written as UTF-8 with a `CSET` saying so.
@Suite(.tags(.file))
final class WaveINFOCharsetTests: BinTestCase {
    private static let utf8CodePage = 65001

    /// `tabla.wav` with an INFO title of `title` and, when `codePage` is given, a `CSET` declaring it.
    private func wave(title: Data, codePage: Int?) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" || $0.id == "CSET" }
            chunks.append(RIFFChunkBuilder.list("INFO", [RIFFChunks.Chunk(id: "INAM", payload: title + Data([0]))]))
            if let codePage {
                chunks.append(cset(codePage))
            }
        }

        return url
    }

    private func cset(_ codePage: Int) -> RIFFChunks.Chunk {
        RIFFChunks.Chunk(id: "CSET", payload: RIFFChunkBuilder.le16(codePage) + Data(count: 6))
    }

    private func save(_ file: WaveFileC) {
        file.markersNeedsSave = false
        file.artworkNeedsSave = false
        #expect(file.save())
    }

    @Test func undeclaredUTF8IsReadAsUTF8() async throws {
        let url = try wave(title: Data("テスト曲 Ölé".utf8), codePage: nil)

        let file = WaveFileC(path: url.path)
        #expect(file.load())
        #expect(file[info: .title] == "テスト曲 Ölé")
    }

    @Test func declaredCodePageIsReadAndSavedAsUTF8() async throws {
        // "Ölé" in Windows-1252.
        let url = try wave(title: Data([0xD6, 0x6C, 0xE9]), codePage: 1252)

        let file = WaveFileC(path: url.path)
        #expect(file.load())
        #expect(file[info: .title] == "Ölé")

        file[info: .artist] = "Ärτιst"
        save(file)

        let riff = try RIFFChunks(contentsOf: url)
        #expect(riff.chunks.filter { $0.id == "CSET" } == [cset(Self.utf8CodePage)])

        let reloaded = WaveFileC(path: url.path)
        #expect(reloaded.load())
        #expect(reloaded[info: .title] == "Ölé")
        #expect(reloaded[info: .artist] == "Ärτιst")
    }

    @Test func savedINFOIsDeclaredUTF8() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        let file = WaveFileC(path: url.path)
        #expect(file.load())
        file[info: .title] = "Ölé"
        save(file)

        let riff = try RIFFChunks(contentsOf: url)
        #expect(riff.chunks.filter { $0.id == "CSET" } == [cset(Self.utf8CodePage)])
    }

    /// Undeclared INFO text that isn't valid UTF-8, as Soundminer writes a Latin-1 `©`, is read as
    /// Latin-1 and survives a save of another field, rewritten as UTF-8.
    @Test func undeclaredLatin1SurvivesTitleSave() async throws {
        let copyright = "© 2019 BOOM Library"
        let latin1 = Data([0xA9]) + Data(" 2019 BOOM Library".utf8) + Data([0])
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" || $0.id == "CSET" }
            chunks.append(RIFFChunkBuilder.list("INFO", [
                RIFFChunks.Chunk(id: "INAM", payload: Data("Title\0".utf8)),
                RIFFChunks.Chunk(id: "IARL", payload: latin1),
                RIFFChunks.Chunk(id: "BCPR", payload: latin1),
            ]))
        }

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties.customTags["ARCHIVALLOCATION"] == copyright)
        #expect(description.tagProperties.customTags["BCPR"] == copyright)

        description.tagProperties[.title] = "New Title"
        try description.save(dirtyFlags: [.tags])

        let riff = try RIFFChunks(contentsOf: url)
        let items = try #require(riff.list("INFO")).subchunks()
        let utf8 = Data(copyright.utf8) + Data([0])
        #expect(items.first { $0.id == "IARL" }?.payload.prefix(utf8.count) == utf8)
        #expect(items.first { $0.id == "BCPR" }?.payload.prefix(utf8.count) == utf8)
        #expect(riff.chunks.filter { $0.id == "CSET" } == [cset(Self.utf8CodePage)])
    }

    @Test func removingINFORemovesCSET() async throws {
        let url = try wave(title: Data("Title".utf8), codePage: Self.utf8CodePage)

        let file = WaveFileC(path: url.path)
        #expect(file.load())
        file.infoDictionary.removeAllObjects()
        file.id3Properties.removeAllObjects()
        save(file)

        let riff = try RIFFChunks(contentsOf: url)
        #expect(riff.list("INFO") == nil)
        #expect(riff.first("CSET") == nil)
    }
}
