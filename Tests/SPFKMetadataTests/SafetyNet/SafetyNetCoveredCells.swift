// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// Cells another test already asserts with a reader independent of this package, so the net
/// leaves them out rather than checking them twice.
enum SafetyNetCoveredCells {
    private struct Entry {
        let row: String
        let kinds: Set<SaveKind>
        let item: SafetyNetItem
        let coveringTest: String
    }

    private static let table: [Entry] = [
        Entry(row: "mp3", kinds: [.k1], item: .id3(.xmpPacket), coveringTest: "XMPStorageSurvivalTests.anMP3TagSaveKeepsTheXMPPrivateFrame"),
        Entry(row: "mp3", kinds: [.k16], item: .id3(.xmpPacket), coveringTest: "StoredXMPPacketWriteTests.anMP3SaveStoresTheReplacementPacket"),
        Entry(row: "mp3", kinds: [.k17], item: .id3(.xmpPacket), coveringTest: "StoredXMPPacketWriteTests.anMP3SaveRemovesThePacket"),
        Entry(row: "mp3", kinds: [.k1], item: .id3(.privateFrame), coveringTest: "MP3TagSavePreservationTests.otherApplicationsFramesSurviveATitleSave"),
        Entry(row: "mp3", kinds: [.k1], item: .id3(.generalObject), coveringTest: "MP3TagSavePreservationTests.otherApplicationsFramesSurviveATitleSave"),
    ]

    /// The test that already covers this cell, or nil when the net checks it.
    static func coveringTest(row: SafetyNetRow, kind: SaveKind, item: SafetyNetItem) -> String? {
        table.first { $0.row == row.name && $0.kinds.contains(kind) && $0.item == item }?.coveringTest
    }
}
