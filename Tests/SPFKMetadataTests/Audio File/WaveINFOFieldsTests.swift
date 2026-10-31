// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// INFO fields no `TagKey` maps are `riffInfoFields`, written to INFO alone; mapped fields are the
/// tags, and each is written only when its own tag changed.
@Suite(.tags(.file))
final class WaveINFOFieldsTests: BinTestCase {
    private let latin1Copyright = Data("Copyright: (P) ".utf8) + Data([0xA9]) + Data(" 1996".utf8)

    private func wave(withInfo items: [(String, Data)], id3: [Data]? = nil) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        if let id3 {
            try ID3v24TagBuilder.replaceWAVTag(in: url, with: id3)
        }

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" || $0.id == "CSET" }
            chunks.append(RIFFChunkBuilder.list("INFO", items.map { RIFFChunks.Chunk(id: $0.0, payload: $0.1 + Data([0])) }))
        }

        return url
    }

    private func wave(withInfo items: [String: String], id3: [Data]? = nil) throws -> URL {
        try wave(withInfo: items.sorted { $0.key < $1.key }.map { ($0.key, Data($0.value.utf8)) }, id3: id3)
    }

    private func infoPayloads(_ url: URL) throws -> [String: Data] {
        let subchunks = try RIFFChunks(contentsOf: url).list("INFO")?.subchunks() ?? []
        return Dictionary(subchunks.map { ($0.id, $0.payload) }, uniquingKeysWith: { first, _ in first })
    }

    private func infoText(_ url: URL) throws -> [String: String] {
        Dictionary(try RIFFChunks(contentsOf: url).infoItems().map { ($0.id, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    /// The ID3 user-text descriptions, read as custom tags now that INFO is not.
    private func id3CustomTags(_ url: URL) throws -> [String: String] {
        try TagProperties(url: url).customTags
    }

    // MARK: - Read and save

    @Test func unmappedFieldsAreReadAndATitleSaveCopiesNoneIntoID3() async throws {
        let url = try wave(withInfo: [
            ("INAM", Data("Old Title".utf8)),
            ("BETM", Data("02:00".utf8)),
            ("itrk", Data("14/14".utf8)),
            ("icom", Data("Lower Composer".utf8)),
            ("ICOM", Data("Upper Composer".utf8)),
            ("BCPR", latin1Copyright),
        ])

        let customBefore = try id3CustomTags(url)
        let before = try infoPayloads(url)
        let textBefore = try infoText(url)

        var description = try await MetaAudioFileDescription(parsing: url)
        let fields = try #require(description.riffInfoFields)
        #expect(Set(fields.fields.keys) == ["BETM", "BCPR", "ICOM", "itrk", "icom"])
        #expect(fields.fields["BCPR"] == "Copyright: (P) © 1996")
        #expect(description.tagProperties.customTags.keys.allSatisfy { customBefore[$0] != nil })

        description.tagProperties[.title] = "New Title"
        try description.save(dirtyFlags: [.tags])

        #expect(try id3CustomTags(url) == customBefore)

        let after = try infoPayloads(url)
        for id in ["BETM", "itrk", "icom", "ICOM"] {
            #expect(after[id] == before[id], "\(id)")
        }
        #expect(try infoText(url)["BCPR"] == textBefore["BCPR"])
        #expect(try infoText(url)["INAM"] == "New Title")
    }

    @Test func aFieldEditWritesThatFieldAloneAndARemovalDeletesIt() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BETM": "02:00", "BCPR": "Old", "ICOM": "Kept"])
        let before = try infoPayloads(url)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.riffInfoFields?.fields["BCPR"] = "New"
        description.riffInfoFields?.fields["BETM"] = nil
        try description.save(dirtyFlags: [.tags])

        let after = try infoText(url)
        #expect(after["BCPR"] == "New")
        #expect(after["BETM"] == nil)
        #expect(try infoPayloads(url)["ICOM"] == before["ICOM"])
        #expect(try infoPayloads(url)["INAM"] == before["INAM"])

        let reparsed = try await MetaAudioFileDescription(parsing: url)
        #expect(reparsed.riffInfoFields?.fields == ["BCPR": "New", "ICOM": "Kept"])
    }

    @Test func aLowercaseFieldCanBeRemoved() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "itrk": "14/14", "ITRK": "14/14", "icom": "Lower"])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.riffInfoFields?.fields["itrk"] = nil
        try description.save(dirtyFlags: [.tags])

        let info = try infoText(url)
        #expect(info["itrk"] == nil)
        #expect(info["ITRK"] == "14/14")
        #expect(info["icom"] == "Lower")
    }

    // MARK: - Unread fields

    /// A description stored before the fields existed holds them as custom tags.
    @Test func nilFieldsLeaveINFOAsItIsAndCopyNothingIntoID3() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BETM": "02:00", "BCPR": "Copyright", "ISRF": "1100"])
        let customBefore = try id3CustomTags(url)
        let before = try infoPayloads(url)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.riffInfoFields = nil
        description.tagProperties.customTags["BETM"] = "02:00"
        description.tagProperties.customTags["BCPR"] = "Copyright"
        description.tagProperties.customTags["SOURCEFORM"] = "1100"
        description.tagProperties[.title] = "New Title"
        try description.save(dirtyFlags: [.tags])

        #expect(try id3CustomTags(url) == customBefore)

        let after = try infoPayloads(url)
        for id in ["BETM", "BCPR", "ISRF"] {
            #expect(after[id] == before[id], "\(id)")
        }
        #expect(try infoText(url)["INAM"] == "New Title")
    }

    @Test func nilFieldsKeepAndUpdateACustomTagTheFileHoldsInID3() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BETM": "02:00"])

        var planted = try await MetaAudioFileDescription(parsing: url)
        planted.tagProperties.customTags["BETM"] = "In ID3"
        try planted.save(dirtyFlags: [.tags])
        #expect(try id3CustomTags(url)["BETM"] == "In ID3")

        var description = try await MetaAudioFileDescription(parsing: url)
        description.riffInfoFields = nil
        description.tagProperties.customTags["BETM"] = "Updated"
        try description.save(dirtyFlags: [.tags])

        #expect(try id3CustomTags(url)["BETM"] == "Updated")
        #expect(try infoText(url)["BETM"] == "02:00")
    }

    /// A `TXXX` an earlier save copied beside its INFO field is left as both.
    @Test func anEarlierCopyReadsAsBothAndASaveKeepsBoth() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BCPR": "Copyright"])

        var planted = try await MetaAudioFileDescription(parsing: url)
        planted.tagProperties.customTags["BCPR"] = "Copyright"
        try planted.save(dirtyFlags: [.tags])

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties.customTags["BCPR"] == "Copyright")
        #expect(description.riffInfoFields?.fields["BCPR"] == "Copyright")

        description.tagProperties[.title] = "New Title"
        try description.save(dirtyFlags: [.tags])

        #expect(try id3CustomTags(url)["BCPR"] == "Copyright")
        #expect(try infoText(url)["BCPR"] == "Copyright")
    }

    // MARK: - Mapped fields

    @Test func aMappedFieldIsRewrittenOnlyWhenItsTagChanges() async throws {
        let url = try wave(withInfo: ["INAM": "Old Title"], id3: [ID3v24TagBuilder.tit2("New Title")])

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties[.title] == "New Title")
        #expect(description.riffInfoFields?.infoTitle == "Old Title")

        description.tagProperties[.artist] = "Artist"
        try description.save(dirtyFlags: [.tags])
        #expect(try infoText(url)["INAM"] == "Old Title")
        #expect(try infoText(url)["IART"] == "Artist")

        description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.riffInfoFields?.infoTitle == "Old Title")

        description.tagProperties[.title] = "Edited"
        try description.save(dirtyFlags: [.tags])
        #expect(try infoText(url)["INAM"] == "Edited")

        description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.riffInfoFields?.infoTitle == nil)

        description.tagProperties[.title] = nil
        try description.save(dirtyFlags: [.tags])
        #expect(try infoText(url)["INAM"] == nil)
    }

    @Test func aClearedTagRemovesItsAlternateFieldsToo() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "ITRK": "3", "IPRT": "3"], id3: [ID3v24TagBuilder.tit2("Title")])

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties[.trackNumber] == "3")

        description.tagProperties[.trackNumber] = nil
        try description.save(dirtyFlags: [.tags])

        let info = try infoText(url)
        #expect(info["ITRK"] == nil)
        #expect(info["IPRT"] == nil)

        let reparsed = try await MetaAudioFileDescription(parsing: url)
        #expect(reparsed.tagProperties[.trackNumber] == nil)
    }

    /// ID3 wins on read, and an unrelated edit leaves a mapped field holding binary as read,
    /// control bytes included.
    @Test func id3WinsAndABinaryTrackFieldSurvivesAnUnrelatedEdit() async throws {
        let binary = Data((0 ..< 16).map { UInt8($0 * 13 + 1) })
        let url = try wave(withInfo: [("INAM", Data("Title".utf8)), ("ITRK", binary)])
        let before = try infoPayloads(url)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.trackNumber] = "10/14"
        try description.save(dirtyFlags: [.tags])

        let numbered = try infoPayloads(url)["ITRK"]

        description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties[.trackNumber] == "10/14")

        description.tagProperties[.artist] = "Artist"
        try description.save(dirtyFlags: [.tags])
        #expect(try infoPayloads(url)["ITRK"] == numbered)
        #expect(numbered != before["ITRK"])

        let untouched = try wave(withInfo: [("INAM", Data("Title".utf8)), ("ITRK", binary)])
        var other = try await MetaAudioFileDescription(parsing: untouched)
        other.tagProperties[.artist] = "Artist"
        try other.save(dirtyFlags: [.tags])
        // TagLib re-renders every INFO field on a save, so a Latin-1 read comes back as UTF-8.
        let kept = try infoPayloads(untouched)["ITRK"].flatMap { String(data: $0.prefix { $0 != 0 }, encoding: .utf8) }
        #expect(kept == String(data: binary, encoding: .isoLatin1))
    }

    @Test func id3TrackWinsOverINFOTrack() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "ITRK": "14/14"])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.trackNumber] = "10/14"
        try description.save(dirtyFlags: [.tags])

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.removeAll { $0.listType == "INFO" || $0.id == "CSET" }
            chunks.append(RIFFChunkBuilder.list("INFO", [RIFFChunks.Chunk(id: "ITRK", payload: Data("14/14\0".utf8))]))
        }

        let reparsed = try await MetaAudioFileDescription(parsing: url)
        #expect(reparsed.tagProperties[.trackNumber] == "10/14")
    }

    // MARK: - Refresh

    @Test func refreshMovesINFOCustomTagsIntoTheFields() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BETM": "02:00", "ISRF": "1100"])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.riffInfoFields = nil
        description.tagProperties.customTags["BETM"] = "02:00"
        description.tagProperties.customTags["SOURCEFORM"] = "1100"
        description.tagProperties.customTags["MINE"] = "Kept"
        #expect(description.hasStaleTagRead)
        #expect(description.staleTagReadRecoversText() == nil)

        let refreshed = description.refreshStaleTagRead()
        #expect(refreshed)
        #expect(description.tagProperties.customTags == ["MINE": "Kept"])
        #expect(description.riffInfoFields?.fields == ["BETM": "02:00", "ISRF": "1100"])
        #expect(!description.hasStaleTagRead)
    }

    @Test func aDescriptionWithoutCustomTagsIsNotReadForItsFields() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BETM": "02:00"])

        var description = try await MetaAudioFileDescription(parsing: url)
        description.riffInfoFields = nil
        description.tagProperties.customTags = [:]

        #expect(!description.hasStaleTagRead)
    }

    /// The read a selection makes of a row stored before the fields existed.
    @Test func aDescriptionLackingFieldsReadsThemOnce() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BETM": "02:00"])
        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.append(RIFFChunks.Chunk(id: "DISP", payload: RIFFChunkBuilder.le32(1) + Data("Shown\0".utf8)))
        }

        var description = try await MetaAudioFileDescription(parsing: url)
        description.riffInfoFields = nil
        description.tagProperties.customTags = ["BETM": "02:00"]
        #expect(description.lacksINFOFields)

        let read = description.readINFOFields()
        #expect(read)
        #expect(description.riffInfoFields?.fields == ["BETM": "02:00"])
        #expect(description.riffInfoFields?.displayText == "Shown")
        #expect(description.tagProperties.customTags.isEmpty)

        let again = description.readINFOFields()
        #expect(!again)
    }

    // MARK: - DISP

    private func addDISP(_ payload: Data, to url: URL) throws {
        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.append(RIFFChunks.Chunk(id: "DISP", payload: payload))
        }
    }

    @Test func theDISPTextIsReadAndASaveLeavesTheChunkAsItWas() async throws {
        let url = try wave(withInfo: ["INAM": "Title", "BCPR": "Copyright"])
        let payload = RIFFChunkBuilder.le32(1) + Data("MotionPulse\0\0".utf8)
        try addDISP(payload, to: url)

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.riffInfoFields?.displayText == "MotionPulse")

        description.tagProperties[.title] = "New Title"
        description.riffInfoFields?.fields["BCPR"] = "Changed"
        try description.save(dirtyFlags: [.tags])

        #expect(try RIFFChunks(contentsOf: url).chunks.filter { $0.id == "DISP" }.map(\.payload) == [payload])

        var reloaded = description
        try reloaded.reloadEmbeddedMetadata()
        #expect(reloaded.riffInfoFields?.displayText == "MotionPulse")
    }

    @Test func aFileWithoutDISPHasNoDisplayText() async throws {
        let url = try wave(withInfo: ["INAM": "Title"])
        let description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.riffInfoFields != nil)
        #expect(description.riffInfoFields?.displayText == nil)
    }
}
