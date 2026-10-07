// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// One thing in an Ogg Vorbis or Opus file's comment header. Field names compare case-insensitively.
enum SafetyNetOggItem: String, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    // Owned
    case title, customTag, otherFields, rating, frontCover, frontCoverPixels, chapters

    // Foreign
    case unknownField, multiValuedField, lowerCaseField, vendor, otherPictures

    var description: String {
        switch self {
        case .title: "TITLE"
        case .customTag: SafetyNetSetup.customTagKey
        case .otherFields: "other comment fields"
        case .rating: "RATING + FMPS_RATING"
        case .frontCover: "METADATA_BLOCK_PICTURE(front cover)"
        case .frontCoverPixels: "METADATA_BLOCK_PICTURE(front cover) pixel size"
        case .chapters: "CHAPTERnnn fields"
        case .unknownField: SafetyNetFLACForeign.unknownFieldKey
        case .multiValuedField: SafetyNetFLACForeign.multiValuedFieldKey
        case .lowerCaseField: SafetyNetFLACForeign.lowerCaseFieldKey
        case .vendor: "vendor string"
        case .otherPictures: "METADATA_BLOCK_PICTURE(other)"
        }
    }

    static let ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [
        .tags: [.ogg(.title), .ogg(.customTag), .ogg(.otherFields)],
        .rating: [.ogg(.rating)],
        .artwork: [.ogg(.frontCover), .ogg(.frontCoverPixels)],
        .markers: [.ogg(.chapters)],
    ]

    /// Other applications' fields, planted by ``SafetyNetOggPlant``.
    static let foreignItems: [SafetyNetForeignItem] = [.unknownField, .multiValuedField, .lowerCaseField, .vendor, .otherPictures]
        .map { SafetyNetForeignItem(item: .ogg($0)) }
}

// MARK: - Reading

extension SafetyNetOggItem {
    private static let fieldsReadElsewhere: Set<String> = [
        "TITLE", SafetyNetSetup.customTagKey, "RATING", "FMPS_RATING", "METADATA_BLOCK_PICTURE",
        SafetyNetFLACForeign.unknownFieldKey, SafetyNetFLACForeign.multiValuedFieldKey, SafetyNetFLACForeign.lowerCaseFieldKey.uppercased(),
    ]

    func read(from ogg: OggPackets?) throws -> SafetyNetValue? {
        guard let ogg, let comment = try ogg.comment() else { return nil }

        func text(_ lines: [String]) -> SafetyNetValue? {
            lines.isEmpty ? nil : .text(lines)
        }

        func values(_ key: String) -> SafetyNetValue? {
            text(comment.values(key))
        }

        let pictures = try comment.values("METADATA_BLOCK_PICTURE").map { field in
            guard let payload = Data(base64Encoded: field) else { throw FLACBlocks.ReadError.malformed("METADATA_BLOCK_PICTURE is not base64") }
            return try FLACBlocks.Picture(payload)
        }

        switch self {
        case .title:
            return values("TITLE")

        case .customTag:
            return values(SafetyNetSetup.customTagKey)

        case .unknownField:
            return values(SafetyNetFLACForeign.unknownFieldKey)

        case .multiValuedField:
            return values(SafetyNetFLACForeign.multiValuedFieldKey)

        case .lowerCaseField:
            return values(SafetyNetFLACForeign.lowerCaseFieldKey)

        case .rating:
            return text(comment.fields.filter { ["RATING", "FMPS_RATING"].contains($0.key.uppercased()) }.map { "\($0.key.uppercased())=\($0.value)" }.sorted())

        case .otherFields:
            let others = comment.fields.filter { !Self.fieldsReadElsewhere.contains($0.key.uppercased()) && !$0.key.uppercased().hasPrefix("CHAPTER") }
            return text(others.map { "\($0.key.uppercased())=\($0.value)" }.sorted())

        case .vendor:
            return .text([comment.vendor])

        case .chapters:
            return try text(SafetyNetFLACItem.chapterLines(comment.fields))

        case .frontCover:
            return text(pictures.filter { $0.pictureType == 3 }.map(SafetyNetFLACItem.line))

        case .otherPictures:
            return text(pictures.filter { $0.pictureType != 3 }.map(SafetyNetFLACItem.line).sorted())

        case .frontCoverPixels:
            return text(pictures.filter { $0.pictureType == 3 }.map { picture in
                do { return try SafetyNetImage.pixelSize(of: picture.data) } catch { return "undecodable \(picture.mimeType)" }
            })
        }
    }
}

// MARK: - Expectations

extension SafetyNetOggItem {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        switch self {
        case .title, .customTag, .rating, .frontCover, .frontCoverPixels, .chapters:
            // The same Xiph comment writers as FLAC's fields.
            guard let item = SafetyNetFLACItem(rawValue: rawValue) else { return .unchanged }
            return try item.written(by: kind, after: after)

        default:
            return .unchanged
        }
    }
}
