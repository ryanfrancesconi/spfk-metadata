import AVFoundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import SPFKUtils
import Testing

@Suite(.serialized, .tags(.file))
class MetaAudioFileDescriptionTests: BinTestCase {
    @Test func codableRoundTrip() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let mafDescription = try await MetaAudioFileDescription(parsing: url)
        #expect(mafDescription.tagProperties.tags.count == 28)

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(mafDescription)
        let newObject = try PropertyListDecoder().decode(MetaAudioFileDescription.self, from: data)

        #expect(newObject == mafDescription)
    }

    @Test func saveRoundTrip() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)
        var mafDescription = try await MetaAudioFileDescription(parsing: url)

        let cgImage = try #require(try? await CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich))
        await mafDescription.imageDescription.update(cgImage: cgImage)
        mafDescription.imageDescription.description = "A NEW DESCRIPTION"
        mafDescription.tagProperties[.title] = "NEW TITLE"
        try mafDescription.save(imageNeedsSave: true)

        let updated = try await MetaAudioFileDescription(parsing: url)
        #expect(updated.tagProperties[.title] == "NEW TITLE")
        #expect(updated.imageDescription.cgImage?.width == cgImage.width)
        #expect(updated.imageDescription.description == "A NEW DESCRIPTION")
    }

    @Test func printFormats() async throws {
        for url in TestBundleResources.shared.formats {
            let maf = try await MetaAudioFileDescription(parsing: url)

            Log.debug(maf.fileType, maf.audioFormat?.formatDescription)

            let estimatedDataRate = try await AVAudioFile(forReading: url).estimatedDataRate()
            Log.debug(estimatedDataRate)
        }
    }

    @Test func parseBEXT() async throws {
        let url = TestBundleResources.shared.cowbell_bext_wav
        let maf = try await MetaAudioFileDescription(parsing: url)

        let bext = try #require(maf.bextDescription)

        Log.debug(bext)
    }
}
