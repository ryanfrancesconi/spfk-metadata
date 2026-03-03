// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class ID3FileTests: BinTestCase {
    @Test func xmp() async throws {
        // use the xmp file as it has the non standard PRIV frame
        let url = TestBundleResources.shared.mp3_xmp

        let file = ID3File(path: url.path)
        #expect(file.load())

        // xmp
        Log.debug(file[id3: .private])
    }

    @Test func parse() async throws {
        let url = TestBundleResources.shared.mp3_id3

        let file = ID3File(path: url.path)
        #expect(file.load())

        #expect(file[id3: .album] == "This Is Spinal Tap")
        #expect(file[id3: .artist] == "Spinal Tap")
        #expect(
            file[id3: .comment] == """
                And oh how they danced. The little children of Stonehenge.
                Beneath the haunted moon.
                For fear that daybreak might come too soon.
                """
        )
        #expect(file[id3: .remixer] == "SPFKMetadata")
        #expect(file[id3: .title] == "Stonehenge")
        #expect(file[id3: .bpm] == "666")
    }
}
