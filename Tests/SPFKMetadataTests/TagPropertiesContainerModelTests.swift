import Foundation
import Testing

@testable import SPFKMetadata

// Test TagPropertiesContainerModel protocol via TagData which conforms to it

struct TagPropertiesContainerModelTests {
    // MARK: - subscript

    @Test func subscriptGetSet() {
        var data = TagData()
        data[.title] = "Hello"
        #expect(data[.title] == "Hello")

        data[.title] = nil
        #expect(data[.title] == nil)
    }

    // MARK: - contains

    @Test func containsKey() {
        let data = TagData(tags: [.title: "Test", .album: "Album"])
        #expect(data.contains(key: .title))
        #expect(data.contains(key: .album))
        #expect(!data.contains(key: .artist))
    }

    @Test func containsKeys() {
        let data = TagData(tags: [.title: "Test", .album: "Album", .artist: "Artist"])
        #expect(data.contains(keys: [.title, .album]))
        #expect(data.contains(keys: [.title, .album, .artist]))
        #expect(!data.contains(keys: [.title, .genre]))
    }

    @Test func containsKeysEmpty() {
        let data = TagData(tags: [.title: "Test"])
        #expect(data.contains(keys: []))
    }

    // MARK: - tag / customTag accessors

    @Test func tagAccessors() {
        var data = TagData()
        data.set(tag: .title, value: "Test Title")
        #expect(data.tag(for: .title) == "Test Title")

        data.remove(tag: .title)
        #expect(data.tag(for: .title) == nil)
    }

    @Test func customTagAccessors() {
        var data = TagData()
        data.set(customTag: "MY_TAG", value: "Custom Value")
        #expect(data.customTag(for: "MY_TAG") == "Custom Value")

        data.remove(customTag: "MY_TAG")
        #expect(data.customTag(for: "MY_TAG") == nil)
    }

    // MARK: - set(taglibKey:value:)

    @Test func setTaglibKeyKnown() {
        var data = TagData()
        data.set(taglibKey: "TITLE", value: "My Title")

        // Should be routed to tags, not customTags
        #expect(data.tags[.title] == "My Title")
        #expect(data.customTags.isEmpty)
    }

    @Test func setTaglibKeyUnknown() {
        var data = TagData()
        data.set(taglibKey: "UNKNOWNTAG", value: "Unknown")

        // Should go to customTags
        #expect(data.tags.isEmpty)
        #expect(data.customTags["UNKNOWNTAG"] == "Unknown")
    }

    // MARK: - set(id3Frame:value:)

    @Test func setID3FrameKnown() {
        var data = TagData()
        data.set(id3Frame: .title, value: "My Title")

        #expect(data.tags[.title] == "My Title")
        #expect(data.customTags.isEmpty)
    }

    @Test func setID3FrameUserDefined() {
        var data = TagData()
        data.set(id3Frame: .userDefined, value: "Custom")

        // .userDefined should go to customTags
        #expect(data.tags.isEmpty)
        #expect(data.customTags[ID3FrameKey.userDefined.rawValue] == "Custom")
    }

    @Test func setID3FrameUnmapped() {
        var data = TagData()
        // .picture doesn't map to a TagKey
        data.set(id3Frame: .picture, value: "PictureData")

        #expect(data.tags.isEmpty)
        #expect(data.customTags[ID3FrameKey.picture.taglibKey] == "PictureData")
    }

    // MARK: - set(infoFrame:value:)

    @Test func setInfoFrameKnown() {
        var data = TagData()
        data.set(infoFrame: .title, value: "My Title")

        #expect(data.tags[.title] == "My Title")
        #expect(data.customTags.isEmpty)
    }

    @Test func setInfoFrameUnmapped() {
        var data = TagData()
        data.set(infoFrame: .cinematographer, value: "Roger Deakins")

        // cinematographer has no TagKey mapping
        #expect(data.tags.isEmpty)
        #expect(data.customTags[InfoFrameKey.cinematographer.taglibKey] == "Roger Deakins")
    }

    // MARK: - description

    @Test func descriptionOutput() {
        let data = TagData(
            tags: [.title: "Test Song"],
            customTags: ["MYCUSTOM": "Value"]
        )

        let desc = data.description
        #expect(desc.contains("Test Song"))
        #expect(desc.contains("MYCUSTOM"))
        #expect(desc.contains("Value"))
    }

    // MARK: - merging

    @Test func mergingTags() {
        var data = TagData()

        let dict1: TagKeyDictionary = [.title: "First", .album: "Album1"]
        let dict2: TagKeyDictionary = [.title: "Second", .artist: "Artist1"]

        data.merging(tags: [dict1, dict2])

        // preserve strategy: first wins
        #expect(data.tags[.title] == "First")
        #expect(data.tags[.album] == "Album1")
        #expect(data.tags[.artist] == "Artist1")
    }

    @Test func mergingCustomTags() {
        var data = TagData()

        let dict1 = ["KEY1": "V1", "KEY2": "V2"]
        let dict2 = ["KEY1": "V1_NEW", "KEY3": "V3"]

        data.merging(customTags: [dict1, dict2])

        // preserve: first wins
        #expect(data.customTags["KEY1"] == "V1")
        #expect(data.customTags["KEY2"] == "V2")
        #expect(data.customTags["KEY3"] == "V3")
    }

    // MARK: - removeAll

    @Test func removeAll() {
        var data = TagData(
            tags: [.title: "Test"],
            customTags: ["KEY": "Value"]
        )

        data.removeAll()
        #expect(data.tags.isEmpty)
        #expect(data.customTags.isEmpty)
    }
}
