// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// Other applications' ID3v2 frames, as each would write them.
enum SafetyNetID3Foreign {
    /// The rating frame's owner, which the app reads and writes; a `POPM` with any other is foreign.
    static let ratingEmail = "Windows Media Player 9 Series"

    static let popularimeterEmail = "safetynet@example.com"
    static let userTextDescription = "SafetyNet Foreign"
    static let privateOwner = "com.example.safetynet"
    static let uniqueFileIDOwner = "http://example.com/safetynet"
    static let artist = ["David St. Hubbins", "Nigel Tufnel"]
    static let involvedPeople = ["PRODUCER", "Ian Faith"]

    /// The custom-tag names the reader gives INFO items that have no tag key (`IPLT`).
    static let infoOnlyUserTextDescriptions: Set<String> = ["NUMCOLORS"]

    static func frames() throws -> [Data] {
        typealias Builder = ID3v24TagBuilder

        return try [
            Builder.version3Popularimeter(email: popularimeterEmail, rating: 153, counter: 7),
            Builder.version3PlayCount(42),
            Builder.version3UserText(description: userTextDescription, values: ["Kept"]),
            Builder.version3Owned(id: "PRIV", owner: privateOwner, data: Data([0x53, 0x4E, 0x00, 0xFF, 0x10])),
            Builder.version3GeneralObject(
                mimeType: "application/octet-stream", fileName: "safetynet.bin", description: "Safety Net Object",
                object: Data([0x01, 0x02, 0x00, 0xFE])
            ),
            Builder.version3Owned(id: "UFID", owner: uniqueFileIDOwner, data: Data("SN-0001".utf8)),
            Builder.version3Comment(id: "USLT", language: "eng", description: "Safety Net", text: "Lyrics another app wrote"),
            Builder.version3UserURL(description: "Safety Net Link", url: "https://example.com/safetynet"),
            Builder.version3Comment(id: "COMM", language: "eng", description: "Safety Net Note", text: "A described comment"),
            Builder.version3Comment(id: "COMM", language: "fra", description: "", text: "Un commentaire"),
            Builder.version3TextFrame(id: "TPE1", values: artist),
            Builder.version3TextFrame(id: "IPLS", values: involvedPeople),
            Builder.version3Picture(
                mimeType: "image/jpeg", pictureType: 4, description: "Back Cover",
                data: Data(contentsOf: TestBundleResources.shared.sharksandwich)
            ),
        ]
    }
}

enum SafetyNetID3Plant {
    enum PlantError: Error {
        case noTag(URL)
    }

    /// Re-renders the setup save's tag as ID3v2.3 with no ID3v1 tag, so a save that changes the
    /// layout is seen, and plants the foreign frames in it.
    static func plant(in url: URL) throws {
        guard let tag = try ID3v2Frames.tag(in: url) else { throw PlantError.noTag(url) }
        try ID3v24TagBuilder.replaceTagWithVersion3(in: url, frames: plantedFrames(from: tag.frames, majorVersion: tag.majorVersion))
    }

    /// `frames` as v2.3 frames with the setup's `TPE1` replaced by a two-valued one and its `CTOC`
    /// by one listing the chapters actually present, followed by the foreign frames.
    static func plantedFrames(from frames: [ID3v2Frames.Frame], majorVersion: UInt8) throws -> [Data] {
        let kept = frames.filter { $0.id != "TPE1" && $0.id != "CTOC" }
        let chapterIDs = try frames.filter { $0.id == "CHAP" }.map { try ID3v2Frames.Chapter($0.body, majorVersion: majorVersion).elementID }
        let tableOfContents = chapterIDs.isEmpty ? [] : [ID3v24TagBuilder.version3TableOfContents(elementID: "toc", flags: 0x03, children: chapterIDs)]

        return try kept.map { try ID3v24TagBuilder.version3Frame(rendering: $0, from: majorVersion) }
            + tableOfContents
            + SafetyNetID3Foreign.frames()
    }
}
