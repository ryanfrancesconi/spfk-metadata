import Foundation
@testable import SPFKMetadata
import Testing

struct TagSetTests {
    @Test func titles() {
        #expect(TagSet.common.title == "Common Tags")
        #expect(TagSet.music.title == "Music Tags")
        #expect(TagSet.loudness.title == "Loudness")
        #expect(TagSet.replayGain.title == "Replay Gain")
        #expect(TagSet.utility.title == "Utility")
        #expect(TagSet.other.title == "Other Tags")
    }

    @Test func initFromTitle() {
        for set in TagSet.allCases {
            let recovered = TagSet(title: set.title)
            #expect(recovered == set, "Failed round-trip for \(set)")
        }
    }

    @Test func initFromTitleNil() {
        #expect(TagSet(title: "Invalid") == nil)
    }

    @Test func commonTagsContents() {
        let keys = TagSet.common.keys
        #expect(keys.contains(.title))
        #expect(keys.contains(.album))
        #expect(keys.contains(.artist))
        #expect(keys.contains(.genre))
        #expect(keys.contains(.date))
        #expect(keys.contains(.comment))
        #expect(keys.contains(.trackNumber))
    }

    @Test func musicTagsContents() {
        let keys = TagSet.music.keys
        #expect(keys.contains(.bpm))
        #expect(keys.contains(.composer))
        #expect(keys.contains(.conductor))
        #expect(keys.contains(.initialKey))
        #expect(keys.contains(.lyrics))
    }

    @Test func loudnessTagsContents() {
        let keys = TagSet.loudness.keys
        #expect(keys.contains(.loudnessIntegrated))
        #expect(keys.contains(.loudnessRange))
        #expect(keys.contains(.loudnessTruePeak))
        #expect(keys.contains(.loudnessMaxMomentary))
        #expect(keys.contains(.loudnessMaxShortTerm))
        #expect(keys.count == 5)
    }

    @Test func replayGainTagsContents() {
        let keys = TagSet.replayGain.keys
        #expect(keys.contains(.replayGainTrackGain))
        #expect(keys.contains(.replayGainAlbumGain))
        #expect(keys.count == 7)
    }

    @Test func utilityTagsContents() {
        let keys = TagSet.utility.keys
        #expect(keys.contains(.isrc))
        #expect(keys.contains(.releaseDate))
        #expect(keys.contains(.artistWebpage))
    }

    @Test func allTagKeysAccountedFor() {
        // every TagKey should appear in exactly one TagSet
        var allKeysInSets: [TagKey] = []
        for set in TagSet.allCases {
            allKeysInSets.append(contentsOf: set.keys)
        }

        for key in TagKey.allCases {
            let count = allKeysInSets.filter { $0 == key }.count
            #expect(count == 1, "\(key) appears \(count) times across TagSets (expected 1)")
        }
    }

    @Test func noOverlapBetweenSets() {
        let sets = TagSet.allCases
        for i in 0 ..< sets.count {
            for j in (i + 1) ..< sets.count {
                let overlap = Set(sets[i].keys).intersection(Set(sets[j].keys))
                #expect(overlap.isEmpty, "\(sets[i]) and \(sets[j]) share keys: \(overlap)")
            }
        }
    }
}
