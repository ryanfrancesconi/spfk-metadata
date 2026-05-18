import CoreImage
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import SPFKUtils
import Testing

@Suite(.tags(.file))
class ImageDescriptionTests: BinTestCase {
    @Test func image() async throws {
        let cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
        var desc = ImageDescription()
        await desc.update(cgImage: cgImage)

        let thumbnailImage = try #require(desc.thumbnailImage)

        #expect(thumbnailImage.width == 64)
        #expect(thumbnailImage.height == 64)
    }
}
