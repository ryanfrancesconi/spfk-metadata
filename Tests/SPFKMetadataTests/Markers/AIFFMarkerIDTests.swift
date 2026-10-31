// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// AIFF marker IDs are positive and unique, as the spec requires, and a marker keeps its ID through a
/// save and a re-read.
@Suite(.tags(.file))
final class AIFFMarkerIDTests: BinTestCase {
    /// The IDs in the file's `MARK` chunk, in chunk order.
    private func fileMarkerIDs(_ url: URL) throws -> [Int16] {
        let data = try Data(contentsOf: url)
        let bytes = [UInt8](data)
        var offset = 12

        func u16(_ at: Int) -> Int { Int(bytes[at]) << 8 | Int(bytes[at + 1]) }
        func u32(_ at: Int) -> Int { u16(at) << 16 | u16(at + 2) }

        while offset + 8 <= bytes.count {
            let id = String(decoding: bytes[offset ..< offset + 4], as: UTF8.self)
            let size = u32(offset + 4)

            if id == "MARK" {
                var position = offset + 10
                return (0 ..< u16(offset + 8)).map { _ in
                    let markerID = Int16(bitPattern: UInt16(u16(position)))
                    position += 6
                    let nameLength = Int(bytes[position]) + 1
                    position += nameLength + (nameLength & 1)
                    return markerID
                }
            }

            offset += 8 + size + (size & 1)
        }

        return []
    }

    @Test func writtenIDsArePositiveAndUnique() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        var description = try await MetaAudioFileDescription(parsing: url)
        description.markerCollection.update(markerDescriptions: [
            AudioMarkerDescription(name: "A", startTime: 0.5),
            AudioMarkerDescription(name: "B", startTime: 1.0),
            AudioMarkerDescription(name: "C", startTime: 1.5),
        ])
        try description.save(dirtyFlags: [.markers])

        let ids = try fileMarkerIDs(url)
        #expect(ids.count == 3)
        #expect(ids.allSatisfy { $0 > 0 })
        #expect(Set(ids).count == ids.count)
    }

    @Test func aMarkerKeepsItsIDThroughASave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        var description = try await MetaAudioFileDescription(parsing: url)
        // IDs out of time order, so a positional ID cannot match them by accident.
        let markers = [
            AudioMarkerDescription(name: "First", startTime: 0.5, markerID: 7),
            AudioMarkerDescription(name: "Second", startTime: 1.0, markerID: 0),
            AudioMarkerDescription(name: "Third", startTime: 1.5, markerID: 3),
        ]
        description.markerCollection.update(markerDescriptions: markers)
        try description.save(dirtyFlags: [.markers])

        let reread = try await MetaAudioFileDescription(parsing: url).markerCollection.markerDescriptions
        let idByName = Dictionary(uniqueKeysWithValues: reread.compactMap { m in m.name.map { ($0, m.markerID) } })
        #expect(idByName["First"] == 7)
        #expect(idByName["Second"] == 0)
        #expect(idByName["Third"] == 3)
    }

    /// `tabla.aif` was written with IDs from 0; a save leaves no 0 behind.
    @Test func aSaveRenumbersAZeroID() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        try #require(try fileMarkerIDs(url).contains(0))

        var description = try await MetaAudioFileDescription(parsing: url)
        let count = description.markerCollection.markerDescriptions.count
        try description.save(dirtyFlags: [.markers])

        let ids = try fileMarkerIDs(url)
        #expect(ids.count == count)
        #expect(ids.allSatisfy { $0 > 0 })
        #expect(Set(ids).count == ids.count)
    }
}
