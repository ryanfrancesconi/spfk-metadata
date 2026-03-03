// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class TagLibBridgeTests: BinTestCase {
    @Test func readWriteProperties() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)
        var dict = try #require(TagLibBridge.getProperties(tmpfile.path) as? [String: String])
        #expect(dict["TITLE"] == "Stonehenge")

        // set
        dict["TITLE"] = "New Title"

        // set and save
        let success = TagLibBridge.setProperties(tmpfile.path, dictionary: dict)
        #expect(success)

        // reparse
        dict = try #require(TagLibBridge.getProperties(tmpfile.path) as? [String: String])
        #expect(dict["TITLE"] == "New Title")
    }

    @Test func removeAllTags() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)

        let success = TagLibBridge.removeAllTags(tmpfile.path)
        #expect(success)

        let dict = try #require(TagLibBridge.getProperties(tmpfile.path))

        Log.debug(dict)

        #expect(dict.count == 0)
    }

    @Test func copyMetadata() async throws {
        let source = TestBundleResources.shared.mp3_id3
        let destination = TestBundleResources.shared.tabla_mp4
        let tmpfile = try copyToBin(url: destination)

        let success = TagLibBridge.copyTags(fromPath: source.path, toPath: tmpfile.path)
        #expect(success)

        let dict = try #require(TagLibBridge.getProperties(tmpfile.path) as? [String: String])
        #expect(dict["TITLE"] == "Stonehenge")
    }
}
