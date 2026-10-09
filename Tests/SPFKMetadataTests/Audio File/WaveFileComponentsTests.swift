// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
import SPFKMetadataC
import Testing

@testable import SPFKMetadata

/// A WAV save that wrote the file names each part it left out, rather than calling the whole save
/// failed.
struct WaveFileComponentsTests {
    let url = URL(fileURLWithPath: "/tmp/a.wav")

    @Test func aFailedRatingLeavesTheTagsWritten() {
        #expect(
            WaveFileComponents.rating.incompleteSave(attempted: [.tags, .rating], url: url)
                == .incompleteSave(written: [.tags], failures: [.writeFailed(.rating, url)])
        )
    }

    @Test func everyFailedPartIsNamedInComponentOrder() {
        let failed: WaveFileComponents = [.markers, .artwork]

        #expect(
            failed.incompleteSave(attempted: [.tags, .artwork, .markers], url: url)
                == .incompleteSave(written: [.tags], failures: [.writeFailed(.artwork, url), .writeFailed(.markers, url)])
        )
    }
}
