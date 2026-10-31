// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// A WAV whose ID3v2.3 tag holds only the year of INFO's full `ICRD` date.
@Suite(.tags(.file))
final class WaveINFODatePrecisionTests: BinTestCase {
    /// `tabla.wav` with INFO `ICRD` `infoDate` and a v2.3 ID3 tag holding `TYER` `year`.
    private func wave(infoDate: String, year: String) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let tag = ID3v24TagBuilder.version3Tag(frames: [
            ID3v24TagBuilder.version3TextFrame(id: "TIT2", values: ["Title"]),
            ID3v24TagBuilder.version3TextFrame(id: "TYER", values: [year]),
        ])

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" || $0.id == "CSET" || $0.id == "ID3 " || $0.id == "id3 " }
            chunks.append(RIFFChunkBuilder.list("INFO", [
                RIFFChunks.Chunk(id: "INAM", payload: Data("Title\0".utf8)),
                RIFFChunks.Chunk(id: "ICRD", payload: Data(infoDate.utf8) + Data([0])),
            ]))
            chunks.append(RIFFChunks.Chunk(id: "ID3 ", payload: tag))
        }

        return url
    }

    private func id3Tag(_ url: URL) throws -> ID3v2Frames.Tag {
        let payload = try #require(try IFFChunks.payload(id: "ID3 ", in: url, bigEndian: false))
        return try #require(try ID3v2Frames.tag(in: payload))
    }

    @Test func fullINFODateWinsOverTheID3Year() async throws {
        let description = try await MetaAudioFileDescription(parsing: wave(infoDate: "2026-01-22", year: "2026"))

        #expect(description.tagProperties[.date] == "2026-01-22")
    }

    @Test func conflictingDatesKeepTheID3One() async throws {
        let description = try await MetaAudioFileDescription(parsing: wave(infoDate: "2018-02-08", year: "2019"))

        #expect(description.tagProperties[.date] == "2019")
    }

    /// The full date reaches both chunks, the v2.3 tag splitting it into `TYER` and `TDAT`.
    @Test func unrelatedEditSavesTheFullDateToBothChunks() async throws {
        let url = try wave(infoDate: "2026-01-22", year: "2026")

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "New Title"
        try description.save(dirtyFlags: [.tags])

        let file = WaveFileC(path: url.path)
        #expect(file.load())
        #expect(file[info: .dateCreated] == "2026-01-22")

        let tag = try id3Tag(url)
        #expect(tag.majorVersion == 3)
        #expect(try tag.frames("TYER").map { try ID3v2Frames.textValues($0.body) } == [["2026"]])
        #expect(try tag.frames("TDAT").map { try ID3v2Frames.textValues($0.body) } == [["2201"]])

        let reloaded = try await MetaAudioFileDescription(parsing: url)
        #expect(reloaded.tagProperties[.date] == "2026-01-22")
    }

    // MARK: - Rows read before the version stamp

    /// The description as an unstamped reader left it, holding `date`.
    private func unstampedDescription(of url: URL, date: String?) async throws -> MetaAudioFileDescription {
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties.tags[.date] = date
        description.tagReaderVersion = nil
        return description
    }

    @Test func unstampedYearIsRefreshedToTheFullDate() async throws {
        let url = try wave(infoDate: "2026-01-22", year: "2026")
        var description = try await unstampedDescription(of: url, date: "2026")
        #expect(description.hasStaleTagRead)

        let refreshed = description.refreshStaleTagRead()
        #expect(refreshed)

        #expect(description.tagProperties[.date] == "2026-01-22")
        #expect(description.tagReaderVersion == MetaAudioFileDescription.currentTagReaderVersion)
        #expect(!description.hasStaleTagRead)
    }

    /// A held date the file's doesn't extend is the row's own, and stays.
    @Test func unstampedDateTheFileDoesNotExtendIsKept() async throws {
        let url = try wave(infoDate: "2026-01-22", year: "2026")
        var description = try await unstampedDescription(of: url, date: "2019")

        let refreshed = description.refreshStaleTagRead()
        #expect(refreshed)

        #expect(description.tagProperties[.date] == "2019")
    }

    @Test func editedUnstampedRowReportsTheFullDate() async throws {
        let url = try wave(infoDate: "2026-01-22", year: "2026")
        var description = try await unstampedDescription(of: url, date: "2026")
        description.tagProperties[.title] = "Edited Title"

        #expect(description.staleTagReadRecoversText() == true)
        #expect(description.tagProperties[.date] == "2026")
    }

    @Test func unstampedRowWithoutADateOrEmptyValueIsNotStale() async throws {
        let url = try wave(infoDate: "2026-01-22", year: "2026")
        let description = try await unstampedDescription(of: url, date: nil)

        #expect(!description.hasStaleTagRead)
    }
}
