// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

/// An MP4 `rate` atom may hold its 0–100 rating as text or as an integer, and TagLib also exposes
/// it in the PropertyMap as `RATING`. The rating read is the app's own, on the star scale, whichever
/// form the file uses.
@Suite(.tags(.file))
struct MP4RateAtomTests {
    enum Stored: CustomStringConvertible, Sendable {
        case text(String)
        case integer(UInt8)

        var description: String {
            switch self {
            case let .text(value): "text \(value)"
            case let .integer(value): "integer \(value)"
            }
        }

        var atom: MP4MoovEditor.Node {
            switch self {
            case let .text(value): MP4MoovEditor.Node(type: "rate", children: [.data(type: 1, value: Data(value.utf8))])
            case let .integer(value): MP4MoovEditor.Node(type: "rate", children: [.data(type: 21, value: Data([value]))])
            }
        }
    }

    @Test(arguments: [Stored.text("60"), .integer(60)])
    func aStoredRatingReadsAsStars(stored: Stored) async throws {
        let url = try Self.file(rate: stored)
        defer { try? FileManager.default.removeItem(at: url) }

        let description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties[.rating] == "3")
    }

    @Test(arguments: [Stored.text("60"), .integer(60)])
    func aTitleSaveKeepsTheRating(stored: Stored) async throws {
        let url = try Self.file(rate: stored)
        defer { try? FileManager.default.removeItem(at: url) }

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Edited"
        try description.save(dirtyFlags: [.metadata])

        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.rating] == "3")
    }

    /// Below one star, or off the scale: unrated, never the stored number.
    @Test(arguments: [Stored.text("10"), .text("250"), .integer(10), .integer(0)])
    func aValueWithNoStarsReadsAsUnrated(stored: Stored) async throws {
        let url = try Self.file(rate: stored)
        defer { try? FileManager.default.removeItem(at: url) }

        let description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.tagProperties[.rating] == nil)
    }

    /// The rating travels through its own writer, so a value with no stars is not copied as text.
    @Test func copyingTagsDoesNotCarryAValueWithNoStars() throws {
        let source = try Self.file(rate: .text("10"))
        let destination = try Self.file(rate: .integer(60))
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }

        try TagProperties.copyTags(from: source, to: destination)

        let ilst = try MP4Atoms(contentsOf: destination).box(["moov", "udta", "meta", "ilst"])
        #expect(ilst?.children.contains { $0.type == "rate" } == false)
    }

    /// `tabla.m4a` with its rating atoms replaced by `rate` alone.
    private static func file(rate: Stored) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MP4RateAtom-\(UUID().uuidString).m4a")
        try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_m4a, to: url)

        try MP4MoovEditor.rewrite(url) { moov in
            try moov.edit(["udta", "meta", "ilst"]) { ilst in
                ilst.children.removeAll { $0.type == "rate" || $0.type == "----" }
                ilst.children.append(rate.atom)
            }
        }
        return url
    }
}
