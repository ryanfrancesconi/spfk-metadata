import Foundation
import Testing

@testable import SPFKMetadata

struct TagSetAdditionalTests {
    @Test func sortTagsContents() {
        let keys = TagSet.sortTags
        #expect(keys.contains(.albumArtistSort))
        #expect(keys.contains(.albumSort))
        #expect(keys.contains(.artistSort))
        #expect(keys.contains(.composerSort))
        #expect(keys.contains(.titleSort))
        #expect(keys.count == 5)
    }

    @Test func sortTagsAreInOtherSet() {
        // sort tags should be categorized under the "other" set
        let otherKeys = TagSet.other.keys
        for key in TagSet.sortTags {
            #expect(otherKeys.contains(key), "\(key) should be in TagSet.other")
        }
    }
}
