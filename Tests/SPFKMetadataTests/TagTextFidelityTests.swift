// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// Line breaks, tabs and joiner sequences in tag text survive a read and a save.
@Suite(.tags(.file))
class TagTextFidelityTests: BinTestCase {
    private static let multiLine = "Line one\nLine two\n\tindented"
    private static let joinedEmoji = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"

    private func rawComment(at url: URL) throws -> String {
        let raw = TagFile(path: url.path)
        #expect(raw.load())
        return try #require((raw.dictionary as? [String: String])?["COMMENT"])
    }

    @Test func readKeepsMultiLineComment() throws {
        let url = TestBundleResources.shared.mp3_id3
        let expected = try rawComment(at: url)
        #expect(expected.contains("\n"))

        #expect(try TagProperties(url: url)[.comment] == expected)
    }

    @Test(arguments: [
        TestBundleResources.shared.tabla_flac,
        TestBundleResources.shared.tabla_mp3,
        TestBundleResources.shared.tabla_ogg,
        TestBundleResources.shared.tabla_m4a,
        TestBundleResources.shared.tabla_wav,
    ])
    func writeReadRoundTrip(url: URL) throws {
        let tmpfile = try copyToBin(url: url)

        var props = TagProperties()
        props[.comment] = Self.multiLine
        props[.title] = Self.joinedEmoji
        try props.save(to: tmpfile)

        let loaded = try TagProperties(url: tmpfile)
        #expect(loaded[.comment] == Self.multiLine)
        #expect(loaded[.title] == Self.joinedEmoji)
    }

    @Test func titleEditKeepsExistingMultiLineComment() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        let expected = try rawComment(at: tmpfile)
        #expect(expected.contains("\n"))

        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        maf.tagProperties[.title] = "Edited"
        try maf.save()

        let reparsed = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reparsed.tagProperties[.title] == "Edited")
        #expect(reparsed.tagProperties[.comment] == expected)
    }

    @Test func waveTitleEditKeepsMultiLineComment() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        maf.tagProperties[.comment] = Self.multiLine
        try maf.save()

        var edited = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(edited.tagProperties[.comment] == Self.multiLine)
        edited.tagProperties[.title] = "Edited"
        try edited.save()

        let reparsed = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reparsed.tagProperties[.title] == "Edited")
        #expect(reparsed.tagProperties[.comment] == Self.multiLine)
    }
}
