// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CryptoKit
import Foundation
import SPFKTesting

/// One thing in an MP4: an `ilst` item, another atom, or the QuickTime chapter track as
/// AVFoundation reads it. Item keys compare exactly, so a renamed atom reads as missing.
enum SafetyNetMP4Item: String, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    // Owned
    case title, customTag, otherItems, rating, frontCover, frontCoverPixels, chapters

    // Foreign
    case unknownFreeform, otherMeanFreeform, gaplessInfo, mediaKind, contentRating, multiValuedText
    case otherCovers, neroChapters, userDataCopyright, xmpUUID
    /// QuickTime only: the classic `udta` text atoms (`©nam`, `©ART`, …), `udta/XMP_`, and a
    /// `moov/meta` whose items are named in an `mdta` key table.
    case quickTimeText, xmpUserData, metadataKeys

    var description: String {
        switch self {
        case .otherItems: "other ilst items"
        case .rating: "rate + \(Self.ratingFreeformKey)"
        case .frontCover: "covr(first image)"
        case .frontCoverPixels: "covr(first image) pixel size"
        case .chapters: "QuickTime chapter track (AVFoundation)"
        case .otherCovers: "covr(other images)"
        case .neroChapters: "moov/udta/chpl"
        case .userDataCopyright: "moov/udta/cprt"
        case .xmpUUID: "top-level uuid XMP"
        case .quickTimeText: "moov/udta ©-text atoms"
        case .xmpUserData: "moov/udta/XMP_"
        case .metadataKeys: "moov/meta (mdta keys)"
        default: key ?? rawValue
        }
    }

    /// The `ilst` key an item reads, for the items that are one item.
    var key: String? {
        switch self {
        case .title: "©nam"
        case .customTag: "----:com.apple.iTunes:\(SafetyNetSetup.customTagKey)"
        case .unknownFreeform: "----:com.apple.iTunes:\(SafetyNetMP4Foreign.unknownFreeformName)"
        case .otherMeanFreeform: "----:\(SafetyNetMP4Foreign.otherMean):\(SafetyNetMP4Foreign.otherMeanName)"
        case .gaplessInfo: "----:com.apple.iTunes:iTunSMPB"
        case .mediaKind: "stik"
        case .contentRating: "rtng"
        case .multiValuedText: "©ART"
        default: nil
        }
    }

    static let ratingFreeformKey = "----:com.apple.iTunes:RATING"

    static let ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [
        .tags: [.mp4(.title), .mp4(.customTag), .mp4(.otherItems)],
        .rating: [.mp4(.rating)],
        .artwork: [.mp4(.frontCover), .mp4(.frontCoverPixels)],
        .markers: [.mp4(.chapters)],
    ]

    /// Other applications' items and atoms, planted by ``SafetyNetMP4Plant``.
    static let foreignItems: [SafetyNetForeignItem] = [
        .unknownFreeform, .otherMeanFreeform, .gaplessInfo, .mediaKind, .contentRating, .multiValuedText,
        .otherCovers, .neroChapters, .userDataCopyright, .xmpUUID,
    ].map { SafetyNetForeignItem(item: .mp4($0)) }

    /// A QuickTime movie's: XMP in `udta` rather than a top-level `uuid`, plus its own text atoms
    /// and `mdta` metadata.
    static let quickTimeForeignItems: [SafetyNetForeignItem] =
        foreignItems.filter { $0.item != .mp4(.xmpUUID) } + [.quickTimeText, .xmpUserData, .metadataKeys].map { SafetyNetForeignItem(item: .mp4($0)) }
}

// MARK: - Reading

extension SafetyNetMP4Item {
    /// Keys another item reads, upper-cased: a foreign item renamed by a save stays its own item's
    /// failure rather than becoming this one's too.
    private static let keysReadElsewhere: Set<String> = Set(allCases.compactMap(\.key).map { $0.uppercased() })
        .union(["RATE", ratingFreeformKey.uppercased(), "COVR"])

    func read(from atoms: MP4Atoms?, chapters: [String]?) throws -> SafetyNetValue? {
        guard let atoms else { return nil }

        func text(_ lines: [String]) -> SafetyNetValue? {
            lines.isEmpty ? nil : .text(lines)
        }

        let items = try atoms.items()

        switch self {
        case .otherItems:
            return text(items.filter { !Self.keysReadElsewhere.contains($0.key.uppercased()) }.map(Self.line).sorted())

        case .rating:
            return text(items.filter { $0.key == "rate" || $0.key == Self.ratingFreeformKey }.map(Self.line).sorted())

        case .frontCover:
            return text(try atoms.covers().prefix(1).map(Self.line))

        case .otherCovers:
            return text(try atoms.covers().dropFirst().map(Self.line))

        case .frontCoverPixels:
            return text(try atoms.covers().prefix(1).map { cover in
                do { return try SafetyNetImage.pixelSize(of: cover.value) } catch { return "undecodable type \(cover.type)" }
            })

        case .chapters:
            return chapters.flatMap(text)

        case .neroChapters:
            return atoms.box(["moov", "udta", "chpl"]).map { .bytes($0.bytes) }

        case .userDataCopyright:
            return atoms.box(["moov", "udta", "cprt"]).map { .bytes($0.bytes) }

        case .quickTimeText:
            let atoms = atoms.box(["moov", "udta"])?.children.filter { $0.type.hasPrefix("©") } ?? []
            return atoms.isEmpty ? nil : .bytes(atoms.map(\.bytes).reduce(Data(), +))

        case .xmpUserData:
            return atoms.box(["moov", "udta", "XMP_"]).map { .bytes($0.bytes) }

        case .metadataKeys:
            return atoms.box(["moov", "meta"]).map { .bytes($0.bytes) }

        case .xmpUUID:
            let boxes = atoms.boxes("uuid").filter { $0.payload.starts(with: SafetyNetMP4Foreign.xmpUUID) }
            return boxes.isEmpty ? nil : .bytes(boxes.map(\.bytes).reduce(Data(), +))

        default:
            guard let key else { return nil }
            return text(items.filter { $0.key == key }.flatMap(\.values).map(\.text))
        }
    }

    /// A chapter as AVFoundation lists it: start in seconds, then the title.
    static func chapterLine(start: Double, title: String) -> String {
        String(format: "%.3f \"%@\"", start, title)
    }

    private static func line(_ item: MP4Atoms.Item) -> String {
        "\(item.key)=\(item.values.map(\.text).joined(separator: " | "))"
    }

    private static func line(_ cover: MP4Atoms.DataAtom) -> String {
        "type \(cover.type), \(cover.value.count) bytes, sha256 \(SHA256.hash(data: cover.value).prefix(8).map { String(format: "%02x", $0) }.joined())…"
    }
}

// MARK: - Expectations

extension SafetyNetMP4Item {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        switch self {
        case .title:
            return .value(.text([SafetyNetEdit.title]))

        case .customTag:
            return .value(.text([SafetyNetEdit.customTagValue]))

        case .rating:
            return .value(.text(SafetyNetMP4Foreign.ratingLines))

        case .frontCover:
            return kind.removesArtwork ? .value(nil) : .unpredictable

        case .frontCoverPixels:
            return kind.removesArtwork ? .value(nil) : try .value(.text([SafetyNetEdit.artworkPixelSize()]))

        case .chapters:
            guard !kind.removesMarkers else { return .value(nil) }

            // AVFoundation lists no chapter that starts past the end of the asset.
            let duration = after.mp4Duration ?? .infinity
            let lines = SafetyNetEdit.markers.filter { $0.startTime < duration }.map {
                Self.chapterLine(start: $0.startTime, title: $0.name ?? "")
            }
            return .value(.text(lines))

        default:
            return .unchanged
        }
    }
}
