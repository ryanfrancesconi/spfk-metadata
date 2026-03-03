// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class TagFileTests: BinTestCase {
    @Test func testParse() async throws {
        let tagFile = TagFile(path: TestBundleResources.shared.wav_bext_v2.path)

        #expect(tagFile.load())

        // this is the TagLib properties map
        #expect(
            tagFile.dictionary?["TITLE"] as? String == "Stonehenge"
        )
    }

    @Test func audioProperties() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let file = TagFile(path: url.path)
        #expect(file.load())

        let audioProperties = try #require(file.audioProperties)

        #expect(audioProperties.sampleRate == 44100)
        #expect(audioProperties.bitRate == 129)
        #expect(audioProperties.channelCount == 2)
        #expect(audioProperties.duration == 2.978)
    }
}
