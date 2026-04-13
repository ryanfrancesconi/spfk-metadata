// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class TagPropertiesTests: BinTestCase {
    @available(macOS 12, iOS 16, *)
    @Test func benchmarkTagLib() async throws {
        let tagLibElapsed = try ContinuousClock().measure {
            _ = try TagProperties(url: TestBundleResources.shared.mp3_id3)
        }

        let avElapsed = try await ContinuousClock().measure {
            _ = try await TagPropertiesAV(url: TestBundleResources.shared.mp3_id3)
        }

        Log.debug("TagLib took", tagLibElapsed)
        Log.debug("AV took", avElapsed)
    }

    @Test func parseID3MP3() async throws {
        let properties = try TagProperties(url: TestBundleResources.shared.mp3_id3)
        verify(properties: properties.data)
    }

    @Test func parseID3MP3_AV() async throws {
        let properties = try await TagPropertiesAV(url: TestBundleResources.shared.mp3_id3)
        // verify(properties: properties)

        Log.debug(properties.data)
    }

    @Test func parseID3Wave() async throws {
        Log.debug(TestBundleResources.shared.wav_bext_v2.path)

        let properties = try TagProperties(url: TestBundleResources.shared.wav_bext_v2)
        verify(properties: properties.data)
    }

    @Test func readWriteTagProperties() async throws {
        deleteBinOnExit = false

        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        // source
        let sourcefile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        let source = try TagProperties(url: sourcefile)

        // target
        var output = try TagProperties(url: tmpfile)
        try output.removeAllAndSave(to: tmpfile)

        #expect(output.tags.isEmpty)

        // replace all tags
        output.tags = source.tags
        try output.save(to: tmpfile)

        #expect(output.tags.count == 28)

        let random = Float.random(in: Float.unitIntervalRange)
        output[.title] = "New Title \(random)"
        output[.keywords] = "Keywords!"
        try output.save(to: tmpfile)

        try output.load(url: tmpfile)
        #expect(output[.title] == "New Title \(random)")
        #expect(output[.keywords] == "Keywords!")
    }

    @Test(arguments: TestBundleResources.shared.markerFormats)
    func readFormats(url: URL) async throws {
        let source = try TagProperties(url: TestBundleResources.shared.mp3_id3)

        Log.debug("Parsing", url.lastPathComponent)
        let props = try TagProperties(url: url)
        #expect(props.tags == source.tags)
    }

    @Test func writeFormats() async throws {
        deleteBinOnExit = false

        let source = try TagProperties(url: TestBundleResources.shared.mp3_id3)

        let files = TestBundleResources.shared.formats

        for file in files {
            let copy = try copyToBin(url: file)

            do {
                var copyProps = try TagProperties(url: copy)

                try copyProps.removeAllAndSave(to: copy)
                copyProps.tags = source.tags
                try copyProps.save(to: copy)
                try copyProps.load(url: copy)
                Log.debug(copy.lastPathComponent, copyProps.description)

                #expect(copyProps.tags == source.tags)

            } catch {
                Log.error(error)
            }
        }
    }

    @Test func stripTags() async throws {
        deleteBinOnExit = false

        let files = TestBundleResources.shared.formats

        for file in files {
            let copy = try copyToBin(url: file)

            do {
                var copyProps = try TagProperties(url: copy)
                try copyProps.removeAllAndSave(to: copy)
                try copyProps.load(url: copy)

                Log.debug(copy.lastPathComponent, copyProps.description)

                #expect(copyProps.tags == [:])

            } catch {
                Log.error(error)
            }
        }
    }

    /// Saving with empty customTags must remove existing custom (TXXX) tags from the file.
    @Test func clearCustomTagsOnSave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        // Write custom tags directly via TagLibBridge to simulate pre-existing state
        var dict: [String: String] = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        dict["SPFK_CUSTOM_FOO"] = "bar"
        dict["SPFK_CUSTOM_BAZ"] = "qux"
        TagLibBridge.setProperties(tmpfile.path, dictionary: dict)

        // Confirm custom tags are present on disk
        let loaded = try TagProperties(url: tmpfile)
        #expect(loaded.customTags["SPFK_CUSTOM_FOO"] == "bar")
        #expect(loaded.customTags["SPFK_CUSTOM_BAZ"] == "qux")

        // Save with empty customTags (only standard tags, no custom)
        var cleared = TagProperties()
        cleared[.title] = "Test"
        try cleared.save(to: tmpfile)

        // Custom tags must be gone
        let reloaded = try TagProperties(url: tmpfile)
        #expect(reloaded.customTags["SPFK_CUSTOM_FOO"] == nil)
        #expect(reloaded.customTags["SPFK_CUSTOM_BAZ"] == nil)
        #expect(reloaded[.title] == "Test")
    }

    /// ITUNSMPB is stored as an iTunes freeform atom in M4A files.
    /// Saving with empty tags must remove it.
    @Test func clearITUNSMPBOnSave() async throws {
        let source = TestBundleResources.shared.ituns_mpb_m4a
        let tmpfile = try copyToBin(url: source)

        // Use raw TagLib dictionary to check ITUNSMPB regardless of which bucket it routes to
        let before = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        Log.debug("raw properties before:", before)
        #expect(before["ITUNSMPB"] != nil)

        // Save with empty tags
        var cleared = TagProperties()
        cleared[.title] = "Test"
        try cleared.save(to: tmpfile)

        // ITUNSMPB must be gone from the raw dictionary
        let after = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        Log.debug("raw properties after:", after)
        #expect(after["ITUNSMPB"] == nil)
        #expect(after["TITLE"] == "Test")
    }

    /// AIFF uses ID3v2 in a chunk — custom tags must be cleared on save.
    @Test func aiffCustomTagsClearedOnSave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_aif)

        // Write a custom tag directly
        var dict: [String: String] = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        dict["SPFK_CUSTOM_AIFF"] = "aiff_value"
        TagLibBridge.setProperties(tmpfile.path, dictionary: dict)

        let before = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        #expect(before["SPFK_CUSTOM_AIFF"] == "aiff_value")

        // Save with only a title — custom key must be gone
        var cleared = TagProperties()
        cleared[.title] = "Test"
        try cleared.save(to: tmpfile)

        let after = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        #expect(after["SPFK_CUSTOM_AIFF"] == nil)
        #expect(after["TITLE"] == "Test")
    }

    /// OGG Vorbis uses flat key-value comments — custom tags must be cleared on save.
    @Test func oggCustomTagsClearedOnSave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_ogg)

        // Write a custom tag directly
        var dict: [String: String] = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        dict["SPFK_CUSTOM_OGG"] = "ogg_value"
        TagLibBridge.setProperties(tmpfile.path, dictionary: dict)

        let before = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        #expect(before["SPFK_CUSTOM_OGG"] == "ogg_value")

        // Save with only a title — custom key must be gone
        var cleared = TagProperties()
        cleared[.title] = "Test"
        try cleared.save(to: tmpfile)

        let after = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]
        #expect(after["SPFK_CUSTOM_OGG"] == nil)
        #expect(after["TITLE"] == "Test")
    }

    @Test func customTag() async throws {
        deleteBinOnExit = false
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        var dict: [String: String] = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]

        dict["loudnessValue"] = "-9"
        dict["loudnessRange"] = "-10"
        dict["maxTruePeakLevel"] = "-16"

        TagLibBridge.setProperties(tmpfile.path, dictionary: dict)

        let newFile = try TagProperties(url: tmpfile)
        Log.debug(newFile.customTags)

        let id3File = ID3File(path: tmpfile.path)
        id3File.load()

        Log.debug(id3File.dictionary)
    }

    @Test func audioProperties() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let file = try TagProperties(url: url)

        let audioProperties = try #require(file.audioProperties)

        #expect(audioProperties.sampleRate == 44100)
        #expect(audioProperties.bitRate == 129) // should be 128, taglib reports 129
        #expect(audioProperties.channelCount == 2)
        #expect(audioProperties.duration == 2.978)
    }

    /// Unicode characters must survive a complete save/load round-trip for non-WAV formats.
    /// ID3v2 uses UTF-16 which can encode any Unicode codepoint — this confirms CJK, accented
    /// Latin, and emoji are not corrupted during TagLib write/read.
    @Test func unicodeTagRoundTrip() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        var props = TagProperties()
        props[.title] = "Títulö: 日本語テスト 🎵"
        props[.artist] = "Ärτιst Ölé"
        try props.save(to: tmpfile)

        let reloaded = try TagProperties(url: tmpfile)
        #expect(reloaded[.title] == "Títulö: 日本語テスト 🎵")
        #expect(reloaded[.artist] == "Ärτιst Ölé")
    }
}

extension TagPropertiesTests {
    private func verify(properties: TagPropertiesContainerModel) {
        Log.debug(properties.description)

        #expect(properties.contains(key: .album))
        #expect(properties.contains(key: .albumArtist))
        #expect(properties.contains(key: .remixer))
        #expect(properties.contains(key: .artist))
        #expect(properties.contains(key: .bpm))
        #expect(properties.contains(key: .comment))
        #expect(properties.contains(key: .composer))
        #expect(properties.contains(key: .copyright))
        #expect(properties.contains(key: .date))
        #expect(properties.contains(key: .genre))
        #expect(properties.contains(key: .initialKey))
        #expect(properties.contains(key: .isrc))
        #expect(properties.contains(key: .label))
        #expect(properties.contains(key: .language))
        #expect(properties.contains(key: .lyricist))
        #expect(properties.contains(key: .lyrics))
        #expect(properties.contains(key: .mood))
        #expect(properties.contains(key: .releaseCountry))
        #expect(properties.contains(key: .subtitle))
        #expect(properties.contains(key: .title))
        #expect(properties.contains(key: .trackNumber))

        let tags = properties.tags

        #expect(tags[.album] == "This Is Spinal Tap")
        #expect(tags[.albumArtist] == "Spinal Tap")
        #expect(tags[.remixer] == "SPFKMetadata")
        #expect(tags[.title] == "Stonehenge")
        #expect(tags[.bpm] == "666")
    }
}
