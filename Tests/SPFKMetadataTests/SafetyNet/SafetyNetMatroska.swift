// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CryptoKit
import Foundation
import SPFKTesting

/// One thing in a Matroska file's `Tags`, `Attachments` or `Chapters`. A SimpleTag reads with its
/// tag's target level, `none` where `Targets` stores none (the specification's 50).
enum SafetyNetMatroskaItem: String, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    // Owned
    case title, customTag, otherTags, rating, frontCover, frontCoverPixels

    // Foreign
    case unknownTag, trackTags, chapters, fontAttachment

    var description: String {
        switch self {
        case .title: "TITLE (track level)"
        case .customTag: SafetyNetSetup.customTagKey
        case .otherTags: "other segment-level SimpleTags"
        case .rating: "RATING"
        case .frontCover: "image attachments"
        case .frontCoverPixels: "first image attachment's pixel size"
        case .unknownTag: "\(SafetyNetMatroskaForeign.unknownTagName), with its target level"
        case .trackTags: "track-level tags"
        case .chapters: "Chapters"
        case .fontAttachment: "non-image attachments"
        }
    }

    static let ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [
        .tags: [.matroska(.title), .matroska(.customTag), .matroska(.otherTags)],
        .rating: [.matroska(.rating)],
        .artwork: [.matroska(.frontCover), .matroska(.frontCoverPixels)],
    ]

    /// Other applications' tags, chapters and attachments; WebM, whose specification has no
    /// `Attachments`, gets no font.
    static func foreignItems(font: Bool) -> [SafetyNetForeignItem] {
        ([.unknownTag, .trackTags, .chapters] + (font ? [.fontAttachment] : [])).map { SafetyNetForeignItem(item: .matroska($0)) }
    }
}

// MARK: - Reading

extension SafetyNetMatroskaItem {
    /// The level TagLib writes a track's own tags at.
    private static let trackLevel: UInt64 = 30

    func read(from file: MatroskaElements?) throws -> SafetyNetValue? {
        guard let file else { return nil }

        func text(_ lines: [String]) -> SafetyNetValue? {
            lines.isEmpty ? nil : .text(lines)
        }

        let segmentTags = file.tags.filter { $0.trackUIDs.isEmpty && $0.otherUIDs.isEmpty }
        let segmentLines = segmentTags.flatMap { tag in tag.simpleTags.map { (tag: tag, simpleTag: $0) } }
        let images = file.attachedFiles.filter { $0.mediaType.hasPrefix("image/") }

        func values(_ name: String, where keep: (MatroskaElements.Tag) -> Bool = { _ in true }) -> SafetyNetValue? {
            text(segmentLines.filter { $0.simpleTag.name == name && keep($0.tag) }.map { Self.value(of: $0.simpleTag) })
        }

        switch self {
        case .title:
            return values("TITLE") { $0.targetTypeValue == Self.trackLevel }

        case .customTag:
            return values(SafetyNetSetup.customTagKey)

        case .rating:
            return text(segmentLines.filter { $0.simpleTag.name == "RATING" }.map { "RATING=\(Self.value(of: $0.simpleTag))" })

        case .unknownTag:
            return text(segmentLines.filter { $0.simpleTag.name == SafetyNetMatroskaForeign.unknownTagName }.map { Self.line($0.tag, $0.simpleTag) })

        case .otherTags:
            let others = segmentLines.filter { line in
                let name = line.simpleTag.name
                let isTitle = name == "TITLE" && line.tag.targetTypeValue == Self.trackLevel
                return !isTitle && ![SafetyNetSetup.customTagKey, "RATING", SafetyNetMatroskaForeign.unknownTagName].contains(name)
            }
            return text(others.map { Self.line($0.tag, $0.simpleTag) }.sorted())

        case .trackTags:
            let lines = file.tags.filter { !$0.trackUIDs.isEmpty }.flatMap { tag in
                tag.simpleTags.map { "track \(tag.trackUIDs.map(String.init).joined(separator: ",")) \(Self.line(tag, $0))" }
            }
            return text(lines.sorted())

        case .chapters:
            let chapters = file.elements(MatroskaElements.ID.chapters)
            return chapters.isEmpty ? nil : .bytes(chapters.map(\.payload).reduce(Data(), +))

        case .frontCover:
            return text(images.map(Self.line))

        case .frontCoverPixels:
            return text(images.prefix(1).map { image in
                do { return try SafetyNetImage.pixelSize(of: image.data) } catch { return "undecodable \(image.mediaType)" }
            })

        case .fontAttachment:
            let others = file.attachedFiles.filter { !$0.mediaType.hasPrefix("image/") }
            return others.isEmpty ? nil : .bytes(others.map { Data("\($0.name)|\($0.mediaType)|".utf8) + $0.data }.reduce(Data(), +))
        }
    }

    private static func value(of simpleTag: MatroskaElements.SimpleTag) -> String {
        simpleTag.string ?? simpleTag.binary.map { "\($0.count) binary bytes" } ?? ""
    }

    private static func line(_ tag: MatroskaElements.Tag, _ simpleTag: MatroskaElements.SimpleTag) -> String {
        "level \(tag.targetTypeValue.map(String.init) ?? "none") \(simpleTag.name)=\(value(of: simpleTag))"
    }

    private static func line(_ file: MatroskaElements.AttachedFile) -> String {
        let digest = SHA256.hash(data: file.data).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(file.name), \(file.mediaType), \(file.data.count) bytes, sha256 \(digest)…"
    }
}

// MARK: - Expectations

extension SafetyNetMatroskaItem {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        switch self {
        case .title:
            return .value(.text([SafetyNetEdit.title]))

        case .customTag:
            return .value(.text([SafetyNetEdit.customTagValue]))

        case .rating:
            // Raw stars, as mkvpropedit and ffmpeg pass them through.
            return .value(.text(["RATING=\(SafetyNetEdit.rating)"]))

        case .frontCover:
            return kind == .k6 ? .value(nil) : .unpredictable

        case .frontCoverPixels:
            return kind == .k6 ? .value(nil) : try .value(.text([SafetyNetEdit.artworkPixelSize()]))

        default:
            return .unchanged
        }
    }
}
