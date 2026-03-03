import Foundation
@testable import SPFKMetadata
import Testing

struct TagDataAdditionalTests {
    // MARK: - isEmpty

    @Test func isEmptyWhenBothEmpty() {
        let data = TagData()
        #expect(data.isEmpty)
    }

    @Test func isNotEmptyWithTags() {
        let data = TagData(tags: [.title: "Test"])
        #expect(!data.isEmpty)
    }

    @Test func isNotEmptyWithCustomTags() {
        let data = TagData(customTags: ["KEY": "Value"])
        #expect(!data.isEmpty)
    }

    @Test func isNotEmptyWithBoth() {
        let data = TagData(tags: [.title: "T"], customTags: ["K": "V"])
        #expect(!data.isEmpty)
    }

    // MARK: - Codable

    @Test func codableRoundTrip() throws {
        let original = TagData(
            tags: [.title: "Test Song", .album: "Test Album", .artist: "Test Artist"],
            customTags: ["CUSTOM1": "Value1", "CUSTOM2": "Value2"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TagData.self, from: data)

        #expect(decoded == original)
        #expect(decoded.tags[.title] == "Test Song")
        #expect(decoded.customTags["CUSTOM1"] == "Value1")
    }

    @Test func codableEmpty() throws {
        let original = TagData()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TagData.self, from: data)

        #expect(decoded.isEmpty)
    }

    // MARK: - Hashable

    @Test func hashable() {
        let data1 = TagData(tags: [.title: "Test"])
        let data2 = TagData(tags: [.title: "Test"])
        let data3 = TagData(tags: [.title: "Different"])

        #expect(data1.hashValue == data2.hashValue)
        #expect(data1 != data3)
    }

    // MARK: - remove(data:)

    @Test func removeSelectiveData() {
        var data = TagData(
            tags: [.title: "T1", .album: "A1", .artist: "Ar1"],
            customTags: ["K1": "V1", "K2": "V2", "K3": "V3"]
        )

        let toRemove = TagData(
            tags: [.title: "T1", .artist: "Ar1"],
            customTags: ["K1": "V1", "K3": "V3"]
        )

        data.remove(data: toRemove)

        #expect(data.tags.count == 1)
        #expect(data.tags[.album] == "A1")
        #expect(data.customTags.count == 1)
        #expect(data.customTags["K2"] == "V2")
    }

    // MARK: - merge schemes

    @Test func mergePreserve() {
        let data1 = TagData(tags: [.title: "First"])
        let data2 = TagData(tags: [.title: "Second"])

        let merged = [data1, data2].merge(scheme: .preserve)
        #expect(merged.tags[.title] == "First")
    }

    @Test func mergeReplace() {
        let data1 = TagData(tags: [.title: "First"])
        let data2 = TagData(tags: [.title: "Second"])

        let merged = [data1, data2].merge(scheme: .replace)
        #expect(merged.tags[.title] == "Second")
    }

    @Test func mergeCombine() {
        let data1 = TagData(tags: [.title: "A"])
        let data2 = TagData(tags: [.title: "B"])
        let data3 = TagData(tags: [.title: "C"])

        let merged = [data1, data2, data3].merge(scheme: .combine)
        #expect(merged.tags[.title] == "A, B, C")
    }

    @Test func mergeDisjointKeys() {
        let data1 = TagData(tags: [.title: "T"])
        let data2 = TagData(tags: [.album: "A"])

        let merged = [data1, data2].merge(scheme: .preserve)
        #expect(merged.tags[.title] == "T")
        #expect(merged.tags[.album] == "A")
    }
}
