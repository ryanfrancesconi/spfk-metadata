// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// INFO fields with a ``TagKey`` but no standard ID3 frame, and INFO `ISRC`, which is RIFF Source.
@Suite(.tags(.file))
final class WaveINFOTagKeyTests: BinTestCase {
    /// `tabla.wav`, whose ID3 tag holds `TSRC`, with its INFO replaced by `fields`.
    private func wave(_ fields: [(id: String, text: String)]) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" || $0.id == "CSET" }
            chunks.append(RIFFChunkBuilder.list("INFO", fields.map {
                RIFFChunks.Chunk(id: $0.id, payload: Data($0.text.utf8) + Data([0]))
            }))
        }

        return url
    }

    private func infoIDs(_ url: URL) throws -> [String] {
        try #require(RIFFChunks(contentsOf: url).list("INFO")).subchunks().map(\.id)
    }

    private func info(_ url: URL) -> WaveFileC {
        let file = WaveFileC(path: url.path)
        #expect(file.load())
        return file
    }

    private let tablaISRC = "AA6Q72000047"

    @Test func infoFieldsReadAsTheirKeysAndSaveBackOnce() async throws {
        let url = try wave([
            ("INAM", "Title"),
            ("IARL", "BOOM Library"),
            ("ISBJ", "The SFX Kit"),
            ("ICMS", "Articulated Sounds"),
            ("ISRF", "1100"),
        ])

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties[.archivalLocation] == "BOOM Library")
        #expect(description.tagProperties[.subject] == "The SFX Kit")
        #expect(description.tagProperties[.commissioned] == "Articulated Sounds")
        #expect(description.tagProperties.customTags["SOURCEFORM"] == "1100")
        for key in ["ARCHIVALLOCATION", "SUBJECT", "COMMISSIONED"] {
            #expect(description.tagProperties.customTags[key] == nil, "\(key)")
        }

        description.tagProperties[.title] = "New Title"
        try description.save(dirtyFlags: [.tags])

        var reloaded = try await MetaAudioFileDescription(parsing: url)
        #expect(reloaded.tagProperties[.archivalLocation] == "BOOM Library")
        #expect(reloaded.tagProperties[.subject] == "The SFX Kit")
        #expect(reloaded.tagProperties[.commissioned] == "Articulated Sounds")
        #expect(reloaded.tagProperties.customTags["SOURCEFORM"] == "1100")

        reloaded.tagProperties[.title] = "Newer Title"
        try reloaded.save(dirtyFlags: [.tags])

        let ids = try infoIDs(url)
        for id in ["IARL", "ISBJ", "ICMS", "ISRF"] {
            #expect(ids.filter { $0 == id }.count == 1, "\(id)")
        }

        let file = info(url)
        #expect(file[info: .archivalLocation] == "BOOM Library")
        #expect(file[info: .subject] == "The SFX Kit")
        #expect(file[info: .commissioned] == "Articulated Sounds")
        #expect(file[info: .sourceForm] == "1100")
    }

    @Test func infoSourceAndID3ISRCAreDifferentTags() async throws {
        let url = try wave([("INAM", "Title"), ("ISRC", "AUDIO")])

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties[.source] == "AUDIO")
        #expect(description.tagProperties[.isrc] == tablaISRC)

        description.tagProperties[.isrc] = "USSNT2600001"
        try description.save(dirtyFlags: [.tags])

        let reloaded = try await MetaAudioFileDescription(parsing: url)
        #expect(reloaded.tagProperties[.source] == "AUDIO")
        #expect(reloaded.tagProperties[.isrc] == "USSNT2600001")
        #expect(info(url)[info: .source] == "AUDIO")
    }

    /// The save never keeps INFO `ISRC` from the ID3 ISRC, which shares its TagLib key.
    @Test func removingSourceLeavesNoISRCCodeInINFO() async throws {
        let url = try wave([("INAM", "Title"), ("ISRC", "AUDIO")])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.source] = nil
        try description.save(dirtyFlags: [.tags])

        #expect(try !infoIDs(url).contains("ISRC"))

        let reloaded = try await MetaAudioFileDescription(parsing: url)
        #expect(reloaded.tagProperties[.source] == nil)
        #expect(reloaded.tagProperties[.isrc] == tablaISRC)
    }
}
