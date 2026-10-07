// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting
import Testing

/// One thing in an AIFF's chunks outside its `ID3 ` chunk, which ``SafetyNetID3Item`` reads.
enum SafetyNetAIFFItem: Hashable, Sendable, CustomStringConvertible {
    // Owned
    case markers

    // Foreign
    /// `NAME`, `AUTH`, `ANNO` and `(c) `, AIFF's own text chunks.
    case textChunks
    case comments
    /// An `APPL` chunk, by its signature, compared byte for byte.
    case application(String)

    var description: String {
        switch self {
        case .markers: "MARK"
        case .textChunks: "text chunks"
        case .comments: "COMT"
        case let .application(signature): "APPL \(signature)"
        }
    }

    /// The AIFF rows' owned items: the `ID3 ` chunk's for tags, rating and artwork, `MARK` for markers.
    static let ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [
        .tags: [.id3(.title), .id3(.customTag), .id3(.otherText), .id3(.frameIDUserText), .id3(.duplicateUserText)],
        .rating: [.id3(.rating)],
        .artwork: [.id3(.frontCover), .id3(.frontCoverPixels), .id3(.frontCoverPath)],
        .markers: [.aiff(.markers)],
    ]

    /// Other applications' ID3 frames and AIFF chunks, planted by ``SafetyNetAIFFPlant``.
    static let foreignItems: [SafetyNetForeignItem] =
        SafetyNetID3Item.foreignFrames.map { SafetyNetForeignItem(item: .id3($0)) }
            + ([.textChunks, .comments] + SafetyNetAIFFForeign.applicationSignatures.map(SafetyNetAIFFItem.application))
            .map { SafetyNetForeignItem(item: .aiff($0)) }
}

// MARK: - Reading

extension SafetyNetAIFFItem {
    func read(from aiff: AIFFChunks?) throws -> SafetyNetValue? {
        guard let aiff else { return nil }

        func text(_ lines: [String]) -> SafetyNetValue? {
            lines.isEmpty ? nil : .text(lines)
        }

        switch self {
        case .markers:
            return try text(aiff.markers().sorted { $0.position < $1.position }.map {
                SafetyNetRIFFItem.markerLine(frame: $0.position, name: $0.name)
            })

        case .textChunks:
            return text(SafetyNetAIFFForeign.textChunkIDs.compactMap { id in aiff.text(id).map { "\(id): \($0)" } })

        case .comments:
            return try text(aiff.comments().map { "\($0.timeStamp) marker \($0.markerID): \($0.text)" })

        case let .application(signature):
            let matches = aiff.applications().filter { $0.signature == signature }.map(\.data)
            return matches.isEmpty ? nil : .bytes(matches.reduce(Data(), +))
        }
    }
}

// MARK: - Expectations

extension SafetyNetAIFFItem {
    func written(by kind: SaveKind, after: SafetyNetSnapshot) throws -> SafetyNetWrite {
        switch self {
        case .markers:
            guard !kind.removesMarkers else { return .value(nil) }
            let sampleRate = try #require(after.aiff?.sampleRate)
            return .value(.text(SafetyNetEdit.markers.map {
                SafetyNetRIFFItem.markerLine(frame: UInt32(($0.startTime * sampleRate).rounded()), name: $0.name)
            }))

        default:
            return .unchanged
        }
    }
}
