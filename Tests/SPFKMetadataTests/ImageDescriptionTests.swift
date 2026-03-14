import CoreImage
import SPFKBase
import SPFKMetadata
import SPFKTesting
import SPFKUtils
import Testing

@Suite(.tags(.file))
class ImageDescriptionTests: BinTestCase {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)

        @Test func image() async throws {
            let cgImage = try #require(try? await CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich))
            var desc = ImageDescription()
            await desc.update(cgImage: cgImage)

            let thumbnailImage = try #require(desc.thumbnailImage)

            #expect(thumbnailImage.width == 32)
            #expect(thumbnailImage.height == 32)
        }
    #endif
}
