import Foundation
import SPFKBase
import Testing

@testable import SPFKMetadata

struct TagDataTests: TestCaseModel {
    @Test func displayNames() throws {
        for item in TagKey.allCases {
            let displayName = item.displayName

            Log.debug(displayName)

            let new = TagKey(displayName: displayName)

            #expect(item == new)
        }
    }

    @Test func merge() throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)")
        defer { benchmark.stop() }

        let data1 = TagData(tags: [.title: "value1"], customTags: ["CUSTOMTAG1": "CUSTOMVALUE1"])
        let data2 = TagData(tags: [.title: "value2"], customTags: ["CUSTOMTAG1": "CUSTOMVALUE2"])
        let data3 = TagData(tags: [.title: "value3"], customTags: ["CUSTOMTAG1": "CUSTOMVALUE3"])

        let preserve = [data1, data2, data3].merge(scheme: .preserve)
        let replace = [data1, data2, data3].merge(scheme: .replace)
        let combine = [data1, data2, data3].merge(scheme: .combine)

        Log.debug("preserve", preserve)
        #expect(preserve.tags[.title] == "value1")
        #expect(preserve.customTags["CUSTOMTAG1"] == "CUSTOMVALUE1")

        Log.debug("replace", replace)
        #expect(replace.tags[.title] == "value3")
        #expect(replace.customTags["CUSTOMTAG1"] == "CUSTOMVALUE3")

        Log.debug("combine", combine)
        #expect(combine.tags[.title] == "value1, value2, value3")
        #expect(combine.customTags["CUSTOMTAG1"] == "CUSTOMVALUE1, CUSTOMVALUE2, CUSTOMVALUE3")
    }

    @Test func remove() throws {
        var data = TagData(
            tags: [.title: "value1", .album: "album1"],
            customTags: ["CUSTOMTAG1": "CUSTOMVALUE1", "CUSTOMTAG2": "CUSTOMVALUE2"]
        )

        let dataToRemove = TagData(
            tags: [.title: "value1"],
            customTags: ["CUSTOMTAG1": "CUSTOMVALUE1"]
        )

        data.remove(data: dataToRemove)

        #expect(
            data
                == TagData(
                    tags: [.album: "album1"],
                    customTags: ["CUSTOMTAG2": "CUSTOMVALUE2"]
                ))
    }
}
