// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CryptoKit
import Foundation
import SPFKTesting

/// One thing in a leading ID3v2 tag. The owned items are what the app writes; the rest are other
/// applications' frames and the tag's layout, which no save of ours may change.
enum SafetyNetID3Item: String, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    // Owned
    case title, customTag, otherText, frameIDUserText, duplicateUserText, infoUserText, rating, frontCover, frontCoverPixels, frontCoverPath, chapters, tableOfContents, xmpPacket

    // Foreign
    case otherPopularimeter, playCount, userText, privateFrame, generalObject, uniqueFileID
    case lyrics, userURL, comments, artist, involvedPeople, otherPictures

    // Layout
    case majorVersion, id3v1

    var description: String {
        switch self {
        case .title: "TIT2"
        case .customTag: "TXXX:\(SafetyNetSetup.customTagKey)"
        case .otherText: "other text frames"
        case .frameIDUserText: "TXXX named after a frame ID"
        case .duplicateUserText: "TXXX descriptions used twice"
        case .infoUserText: "TXXX holding an INFO-only item"
        case .rating: "POPM(\(SafetyNetID3Foreign.ratingEmail))"
        case .frontCover: "APIC(front cover)"
        case .frontCoverPixels: "APIC(front cover) pixel size"
        case .frontCoverPath: "APIC(front cover) description naming the file's location"
        case .chapters: "CHAP"
        case .tableOfContents: "CTOC children"
        case .xmpPacket: "PRIV(XMP)"
        case .otherPopularimeter: "POPM(other)"
        case .playCount: "PCNT"
        case .userText: "TXXX(other)"
        case .privateFrame: "PRIV(other)"
        case .generalObject: "GEOB"
        case .uniqueFileID: "UFID"
        case .lyrics: "USLT"
        case .userURL: "WXXX"
        case .comments: "COMM"
        case .artist: "TPE1"
        case .involvedPeople: "TIPL"
        case .otherPictures: "APIC(other)"
        case .majorVersion: "major version"
        case .id3v1: "ID3v1 tag"
        }
    }

    static let ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [
        .tags: [.id3(.title), .id3(.customTag), .id3(.otherText), .id3(.frameIDUserText), .id3(.duplicateUserText), .id3(.infoUserText)],
        .rating: [.id3(.rating)],
        .artwork: [.id3(.frontCover), .id3(.frontCoverPixels), .id3(.frontCoverPath)],
        .markers: [.id3(.chapters), .id3(.tableOfContents)],
        .packet: [.id3(.xmpPacket)],
    ]

    /// Other applications' frames, wherever the tag sits.
    static let foreignFrames: [SafetyNetID3Item] = [
        .otherPopularimeter, .playCount, .userText, .privateFrame, .generalObject, .uniqueFileID,
        .lyrics, .userURL, .comments, .artist, .involvedPeople, .otherPictures,
    ]

    /// An MP3's foreign frames and the layout of its leading tag.
    static let foreignItems: [SafetyNetForeignItem] = (foreignFrames + [.majorVersion, .id3v1]).map { SafetyNetForeignItem(item: .id3($0)) }
}

// MARK: - Reading

extension SafetyNetID3Item {
    /// The item's value, or nil when the tag has none of it. Lists of frames are sorted, since
    /// order between frames is not compared.
    func read(from tag: ID3v2Frames.Tag?, file: Data, url: URL) throws -> SafetyNetValue? {
        if self == .id3v1 {
            let present = file.count >= 128 && file.suffix(128).starts(with: Data("TAG".utf8))
            return .text([present ? "present" : "absent"])
        }

        guard let tag else { return nil }

        func text(_ lines: [String]) -> SafetyNetValue? {
            lines.isEmpty ? nil : .text(lines)
        }

        func bytes(_ id: String, where keep: (ID3v2Frames.OwnedData) -> Bool = { _ in true }) throws -> SafetyNetValue? {
            let bodies = try tag.frames(id).filter { try keep(ID3v2Frames.OwnedData($0.body)) }.map(\.body)
            return bodies.isEmpty ? nil : .bytes(bodies.reduce(Data(), +))
        }

        let userTexts = try tag.frames("TXXX").map { try ID3v2Frames.UserText($0.body) }
        let popularimeters = try tag.frames("POPM").map { try ID3v2Frames.Popularimeter($0.body) }
        let pictures = try tag.frames("APIC").map { try ID3v2Frames.Picture($0.body) }

        switch self {
        case .majorVersion:
            return .text(["2.\(tag.majorVersion)"])

        case .title:
            return try text(tag.frames("TIT2").flatMap { try ID3v2Frames.textValues($0.body) })

        case .artist:
            return try text(tag.frames("TPE1").flatMap { try ID3v2Frames.textValues($0.body) })

        case .involvedPeople:
            return try text((tag.frames("TIPL") + tag.frames("IPLS")).flatMap { try ID3v2Frames.textValues($0.body) })

        case .customTag:
            return text(userTexts.filter { $0.description == SafetyNetSetup.customTagKey }.flatMap(\.values))

        case .userText:
            let foreign = userTexts.filter { $0.description.caseInsensitiveCompare(SafetyNetID3Foreign.userTextDescription) == .orderedSame }
            return text(foreign.map { "\($0.description): \($0.values.joined(separator: " | "))" })

        case .otherText:
            return try text(Self.otherTextLines(in: tag, userTexts: userTexts))

        // The next three read "none" rather than nothing when absent: the precondition is the
        // absence, and a cell requires every item to be read before the save.
        case .frameIDUserText:
            let copies = userTexts.filter { Self.frameIDDescriptions.contains($0.description.uppercased()) }
            return .text(copies.isEmpty ? ["none"] : copies.map { "\($0.description): \($0.values.joined(separator: " | "))" }.sorted())

        case .duplicateUserText:
            let counts = Dictionary(grouping: userTexts, by: { $0.description.uppercased() }).filter { $0.value.count > 1 }
            return .text(counts.isEmpty ? ["none"] : counts.map { "\($0.key) ×\($0.value.count)" }.sorted())

        case .infoUserText:
            let copies = userTexts.filter { SafetyNetID3Foreign.infoOnlyUserTextDescriptions.contains($0.description.uppercased()) }
            return .text(copies.isEmpty ? ["none"] : copies.map { "\($0.description): \($0.values.joined(separator: " | "))" }.sorted())

        case .rating:
            return text(popularimeters.filter { $0.email == SafetyNetID3Foreign.ratingEmail }.map(Self.line))

        case .otherPopularimeter:
            return text(popularimeters.filter { $0.email != SafetyNetID3Foreign.ratingEmail }.map { "\($0.email), \(Self.line($0))" })

        case .playCount:
            return try text(tag.frames("PCNT").map { try String(ID3v2Frames.playCount($0.body)) })

        case .xmpPacket:
            let packets = try tag.frames("PRIV").map { try ID3v2Frames.OwnedData($0.body) }.filter { $0.owner == "XMP" }
            return packets.isEmpty ? nil : .bytes(packets.map(\.data).reduce(Data(), +))

        case .privateFrame:
            return try bytes("PRIV") { $0.owner != "XMP" }

        case .uniqueFileID:
            return try bytes("UFID")

        case .generalObject:
            let bodies = tag.frames("GEOB").map(\.body)
            return bodies.isEmpty ? nil : .bytes(bodies.reduce(Data(), +))

        case .lyrics, .comments:
            let id = self == .lyrics ? "USLT" : "COMM"
            let comments = try tag.frames(id).map { try ID3v2Frames.Comment($0.body) }
            return text(comments.map { "\($0.language) | \($0.description) | \($0.text)" }.sorted())

        case .userURL:
            let links = try tag.frames("WXXX").map { try ID3v2Frames.UserURL($0.body) }
            return text(links.map { "\($0.description) | \($0.url)" }.sorted())

        case .frontCover:
            return text(pictures.filter { $0.pictureType == 3 }.map(Self.line))

        case .otherPictures:
            return text(pictures.filter { $0.pictureType != 3 }.map(Self.line).sorted())

        case .frontCoverPixels:
            return text(pictures.filter { $0.pictureType == 3 }.map { picture in
                do { return try SafetyNetImage.pixelSize(of: picture.data) } catch { return "undecodable \(picture.mimeType)" }
            })

        case .frontCoverPath:
            let folder = url.deletingLastPathComponent().path
            return text(pictures.filter { $0.pictureType == 3 }.map { picture in
                if picture.description.contains(url.path) { return "names the file's path" }
                return picture.description.contains(folder) ? "names the file's folder" : "names no path"
            })

        case .chapters:
            let chapters = try tag.frames("CHAP").map { try ID3v2Frames.Chapter($0.body, majorVersion: tag.majorVersion) }
            return text(chapters.sorted { $0.startTime < $1.startTime }.map { Self.chapterLine(start: $0.startTime, end: $0.endTime, title: $0.title) })

        case .tableOfContents:
            let tables = try tag.frames("CTOC").map { try ID3v2Frames.TableOfContents($0.body, majorVersion: tag.majorVersion) }
            return tables.isEmpty ? nil : .text(tables.flatMap(\.children))

        case .id3v1:
            return nil
        }
    }

    /// `TXXX` descriptions that name a frame whose text the WAV writer can't map to a property.
    static let frameIDDescriptions: Set<String> = ["USLT", "WXXX", "TIPL", "TMCL", "IPLS"]

    /// Every text frame no other item reads, under its v2.4 ID, as `ID: values`; a repeated line
    /// once, since ``duplicateUserText`` counts repeats.
    private static func otherTextLines(in tag: ID3v2Frames.Tag, userTexts: [ID3v2Frames.UserText]) throws -> [String] {
        let readElsewhere: Set<String> = ["TIT2", "TPE1", "TIPL", "IPLS", "TXXX"]
        let v24ID = ["TYER": "TDRC", "TORY": "TDOR"]

        let frames = try tag.frames.filter { $0.id.hasPrefix("T") && !readElsewhere.contains($0.id) }.map { frame in
            try "\(v24ID[frame.id] ?? frame.id): \(ID3v2Frames.textValues(frame.body).joined(separator: " | "))"
        }

        let owned = [SafetyNetSetup.customTagKey, SafetyNetID3Foreign.userTextDescription]
        let readElsewhereTXXX = frameIDDescriptions.union(SafetyNetID3Foreign.infoOnlyUserTextDescriptions)
        let others = userTexts.filter { text in !owned.contains { $0.caseInsensitiveCompare(text.description) == .orderedSame } }
            .filter { !readElsewhereTXXX.contains($0.description.uppercased()) }
            .map { "TXXX:\($0.description): \($0.values.joined(separator: " | "))" }

        return Array(Set(frames + others)).sorted()
    }

    private static func line(_ popularimeter: ID3v2Frames.Popularimeter) -> String {
        "rating \(popularimeter.rating), counter \(popularimeter.counter.map(String.init) ?? "absent")"
    }

    private static func line(_ picture: ID3v2Frames.Picture) -> String {
        let digest = SHA256.hash(data: picture.data).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "type \(picture.pictureType), \(picture.mimeType), \"\(picture.description)\", sha256 \(digest)…"
    }

    static func chapterLine(start: UInt32, end: UInt32, title: String?) -> String {
        "\(start)–\(end) ms \(title ?? "untitled")"
    }
}

// MARK: - Expectations

extension SafetyNetID3Item {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        func milliseconds(_ seconds: TimeInterval) -> UInt32 {
            UInt32((seconds * 1000).rounded())
        }

        switch self {
        case .title:
            return .value(.text([SafetyNetEdit.title]))

        case .customTag:
            return .value(.text([SafetyNetEdit.customTagValue]))

        case .rating:
            return .value(.text(["rating \(SafetyNetEdit.popmRating), counter 0"]))

        case .frontCover:
            return kind == .k6 ? .value(nil) : .unpredictable

        case .frontCoverPixels:
            return kind == .k6 ? .value(nil) : try .value(.text([SafetyNetEdit.artworkPixelSize()]))

        case .frontCoverPath:
            return .value(kind == .k6 ? nil : .text(["names no path"]))

        case .chapters:
            let markers = SafetyNetEdit.markers
            return .value(.text(markers.map {
                Self.chapterLine(start: milliseconds($0.startTime), end: milliseconds($0.endTime ?? $0.startTime), title: $0.name)
            }))

        case .tableOfContents:
            // The table lists exactly the chapters the save left.
            guard let tag = after.id3Tag else { return .value(nil) }
            let ids = try tag.frames("CHAP").map { try ID3v2Frames.Chapter($0.body, majorVersion: tag.majorVersion).elementID }
            return .value(.text(ids))

        case .xmpPacket:
            return .value(kind == .k17 ? nil : .bytes(Data(SafetyNetEdit.packet.utf8)))

        case .infoUserText:
            // An INFO item with no tag key is read as a custom tag and saved like one, into ID3.
            guard let info = try after.riff?.infoItems() else { return .unchanged }

            let copies = SafetyNetID3Foreign.infoOnlyItems.flatMap { id, name in
                info.filter { $0.id == id }.map { "\(name): \($0.value)" }
            }
            return .value(.text(copies.isEmpty ? ["none"] : copies.sorted()))

        default:
            return .unchanged
        }
    }
}
