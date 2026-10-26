// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Key tags as other tools write them, read through each tag family, and written back.
@Suite(.tags(.file, .musicalKey))
final class KeyTagReadTests: BinTestCase {
    @Test(arguments: TestBundleResources.shared.keyTagFixtures)
    func aKeyTagIsReadAsWritten(fixture: KeyTagFixture) throws {
        for url in fixture.urls {
            let properties = try TagProperties(url: url)
            #expect(properties[.initialKey] == fixture.initialKey, "\(url.lastPathComponent)")
            #expect(properties[.comment] == fixture.comment, "\(url.lastPathComponent)")
        }
    }

    @Test(arguments: [MusicalKeyNotation.short, .camelot])
    func anOrganizedKeyIsWrittenToEveryFamily(notation: MusicalKeyNotation) throws {
        let fixture = try #require(TestBundleResources.shared.keyTagFixtures.first { $0.initialKey == "C# Minor" })
        let expected = notation == .short ? "C#m" : "12A"

        for source in fixture.urls {
            let url = try copyToBin(url: source)
            var properties = try TagProperties(url: url)
            properties.setInitialKey(try #require(properties[.initialKey]), notation: notation)
            try properties.save(to: url)

            #expect(try TagProperties(url: url)[.initialKey] == expected, "\(url.lastPathComponent)")
        }
    }

    /// MusicBrainz Picard writes Vorbis `KEY`. Nothing maps it to the key tag, so the app sees
    /// no key for such a file and keeps the text as a custom tag.
    @Test func aVorbisKEYCommentIsNotTheKeyTag() throws {
        let properties = try TagProperties(url: TestBundleResources.shared.keyTagVorbisKEY)
        #expect(properties[.initialKey] == nil)
        #expect(properties.data.customTags["KEY"] == "Am")
    }
}
