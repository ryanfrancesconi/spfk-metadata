import Foundation
@testable import SPFKMetadata
import Testing

struct ImageDescriptionCodableTests {
    @Test func codableRoundTripEmpty() throws {
        let original = ImageDescription()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageDescription.self, from: data)

        #expect(decoded.thumbnailData == nil)
        #expect(decoded.description == nil)
        #expect(decoded.cgImage == nil)
    }

    @Test func codableWithDescription() throws {
        var original = ImageDescription()
        original.description = "Album art"

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageDescription.self, from: data)

        #expect(decoded.description == "Album art")
    }

    @Test func codableWithThumbnailData() throws {
        var original = ImageDescription()
        original.description = "Test"

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageDescription.self, from: data)

        // cgImage is deliberately not encoded
        #expect(decoded.cgImage == nil)
        #expect(decoded.description == "Test")
    }
}

struct ImageDescriptionEquatableTests {
    @Test func equalWhenBothEmpty() {
        let a = ImageDescription()
        let b = ImageDescription()
        #expect(a == b)
    }

    @Test func equalWithSameDescription() {
        var a = ImageDescription()
        a.description = "Test"
        var b = ImageDescription()
        b.description = "Test"
        #expect(a == b)
    }

    @Test func notEqualDifferentDescription() {
        var a = ImageDescription()
        a.description = "A"
        var b = ImageDescription()
        b.description = "B"
        #expect(a != b)
    }
}

struct ImageDescriptionInitTests {
    @Test func defaultInit() {
        let desc = ImageDescription()
        #expect(desc.cgImage == nil)
        #expect(desc.thumbnailImage == nil)
        #expect(desc.thumbnailData == nil)
        #expect(desc.description == nil)
        #expect(desc.needsSave == false)
    }
}
