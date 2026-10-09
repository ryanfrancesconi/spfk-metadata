// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Another application's `adtl` `note` and `ltxt` follow their cue point through a marker save,
/// and are dropped with it.
@Suite(.tags(.file))
final class WAVMarkerAssociatedDataTests: BinTestCase {
    /// `tabla.wav`'s cue points are IDs 0–4, one second apart.
    static let note = RIFFChunks.Chunk(id: "note", payload: RIFFChunkBuilder.le32(1) + Data("On cue one".utf8) + Data([0]))
    static let ltxt = RIFFChunks.Chunk(
        id: "ltxt",
        payload: RIFFChunkBuilder.le32(3) + RIFFChunkBuilder.le32(4800) + Data("rgn ".utf8)
            + [0, 0, 0, 0].map(RIFFChunkBuilder.le16).reduce(Data(), +) + Data("On cue three".utf8) + Data([0])
    )

    private func plantedFile() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            guard let index = chunks.firstIndex(where: { $0.listType == "adtl" }) else { throw RIFFChunkBuilder.MissingChunk() }
            let subchunks = try chunks[index].subchunks()
            chunks[index] = RIFFChunkBuilder.list("adtl", subchunks + [Self.note, Self.ltxt])
        }

        return url
    }

    private func saveMarkers(_ url: URL, _ edit: (inout [AudioMarkerDescription]) throws -> Void) async throws {
        var description = try await MetaAudioFileDescription(parsing: url)
        var markers = description.markerCollection.markerDescriptions
        try edit(&markers)
        description.markerCollection.update(markerDescriptions: markers)
        try description.save(dirtyFlags: [.markers])
    }

    private func foreignChunks(_ url: URL) throws -> [RIFFChunks.Chunk] {
        try RIFFChunks(contentsOf: url).associatedData().filter { $0.id != "labl" }
    }

    private func cueID(at frame: UInt32, in url: URL) throws -> UInt32? {
        try RIFFChunks(contentsOf: url).cuePoints().first { $0.sampleOffset == frame }?.id
    }

    @Test func deletingAMarkerDropsItsNoteAndKeepsTheOthers() async throws {
        let url = try plantedFile()

        try await saveMarkers(url) { markers in
            markers.removeAll { $0.markerID == 1 }
        }

        #expect(try foreignChunks(url) == [Self.ltxt])
        #expect(try cueID(at: 144_000, in: url) == 3)
    }

    @Test func aMovedMarkerKeepsItsNote() async throws {
        let url = try plantedFile()

        try await saveMarkers(url) { markers in
            let index = try #require(markers.firstIndex { $0.markerID == 1 })
            markers[index].startTime = 1.5
        }

        #expect(try foreignChunks(url) == [Self.note, Self.ltxt])
        #expect(try cueID(at: 72000, in: url) == 1)
    }

    @Test func aRenamedMarkerKeepsItsNote() async throws {
        let url = try plantedFile()

        try await saveMarkers(url) { markers in
            let index = try #require(markers.firstIndex { $0.markerID == 1 })
            markers[index].name = "Renamed"
        }

        #expect(try foreignChunks(url) == [Self.note, Self.ltxt])
    }

    /// `update(markerDescriptions:)` gives a new marker the lowest free ID, which is the deleted one's.
    @Test func aNewMarkerTakingADeletedMarkersIDDoesNotInheritItsNote() async throws {
        let url = try plantedFile()

        try await saveMarkers(url) { markers in
            markers.removeAll { $0.markerID == 1 }
            markers.append(AudioMarkerDescription(name: "New", startTime: 4.5))
        }

        #expect(try cueID(at: 216_000, in: url) == 1)
        #expect(try foreignChunks(url) == [Self.ltxt])
    }

    @Test func removingEveryMarkerDropsTheAssociatedData() async throws {
        let url = try plantedFile()

        try EmbeddedAudioMarkers.removeAll(from: url, fileType: .wav)

        #expect(try RIFFChunks(contentsOf: url).list("adtl") == nil)
    }
}
