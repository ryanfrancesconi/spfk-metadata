// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A WAV description read before Latin-1 INFO text was readable holds that text as `""`; a refresh
/// fills it from the file and touches nothing else.
@Suite(.tags(.file))
final class WaveStaleTagReadTests: BinTestCase {
    private let copyright = "© 2019 BOOM Library"

    /// `tabla.wav` with a CSET-less INFO holding Latin-1 `©` text in `IARL`.
    private func latin1Wave() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" || $0.id == "CSET" }
            chunks.append(RIFFChunkBuilder.list("INFO", [
                RIFFChunks.Chunk(id: "INAM", payload: Data("Title\0".utf8)),
                RIFFChunks.Chunk(id: "IARL", payload: Data([0xA9]) + Data(" 2019 BOOM Library".utf8) + Data([0])),
            ]))
        }

        return url
    }

    /// The description as an older reader left it: the Latin-1 field empty, no version.
    private func staleDescription(of url: URL) async throws -> MetaAudioFileDescription {
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties.tags[.archivalLocation] = ""
        description.tagReaderVersion = nil
        return description
    }

    @Test func parseStampsTheCurrentVersion() async throws {
        let description = try await MetaAudioFileDescription(parsing: latin1Wave())

        #expect(description.tagReaderVersion == MetaAudioFileDescription.currentTagReaderVersion)
        #expect(!description.hasStaleTagRead)
    }

    @Test func refreshFillsTheEmptyValueAndKeepsTheRest() async throws {
        let url = try latin1Wave()
        var description = try await staleDescription(of: url)
        description.tagProperties[.title] = "Edited Title"
        #expect(description.hasStaleTagRead)

        let refreshed = description.refreshStaleTagRead()
        #expect(refreshed)

        #expect(description.tagProperties.tags[.archivalLocation] == copyright)
        #expect(description.tagProperties[.title] == "Edited Title")
        #expect(description.tagReaderVersion == MetaAudioFileDescription.currentTagReaderVersion)
        #expect(!description.hasStaleTagRead)
    }

    /// A value empty in the file too stays empty, and the stamp keeps it from being read again.
    @Test func refreshOfAGenuinelyEmptyValueOnlyStamps() async throws {
        let url = try latin1Wave()
        var description = try await staleDescription(of: url)
        description.tagProperties.customTags["IZZZ"] = ""

        let refreshed = description.refreshStaleTagRead()
        #expect(refreshed)

        #expect(description.tagProperties.customTags["IZZZ"] == "")
        #expect(!description.hasStaleTagRead)
    }

    @Test func unreachableFileChangesNothing() async throws {
        let url = try latin1Wave()
        var description = try await staleDescription(of: url)
        try FileManager.default.removeItem(at: url)

        let refreshed = description.refreshStaleTagRead()
        #expect(!refreshed)

        #expect(description.tagProperties.tags[.archivalLocation] == "")
        #expect(description.tagReaderVersion == nil)
    }

    @Test func recoverableTextIsReportedWithoutChangingTheDescription() async throws {
        let url = try latin1Wave()
        let stale = try await staleDescription(of: url)

        #expect(stale.staleTagReadRecoversText() == true)
        #expect(stale.tagProperties.tags[.archivalLocation] == "")
    }

    /// Empty in the file too: nothing to recover, so nothing to warn about.
    @Test func nothingToRecoverIsNotReported() async throws {
        let url = try latin1Wave()
        var stale = try await staleDescription(of: url)
        stale.tagProperties.tags[.archivalLocation] = copyright
        stale.tagProperties.customTags["IZZZ"] = ""

        #expect(stale.hasStaleTagRead)
        #expect(stale.staleTagReadRecoversText() == false)
    }

    /// An unreachable file answers nothing, so the row is not recorded as checked.
    @Test func unreachableFileReportsNoAnswer() async throws {
        let url = try latin1Wave()
        let stale = try await staleDescription(of: url)
        try FileManager.default.removeItem(at: url)

        #expect(stale.staleTagReadRecoversText() == nil)
    }

    /// Only WAV INFO was ever read as empty.
    @Test func otherFormatsAreNeverStale() async throws {
        var description = try await MetaAudioFileDescription(parsing: copyToBin(url: TestBundleResources.shared.mp3_id3))
        description.tagProperties[.album] = ""
        description.tagReaderVersion = nil

        #expect(!description.hasStaleTagRead)
    }
}
