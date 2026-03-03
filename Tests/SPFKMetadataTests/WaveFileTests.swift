// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class WaveFileTests: BinTestCase {
    @Test func parseInfo() async throws {
        let url = TestBundleResources.shared.wav_bext_v2
        let file = WaveFileC(path: url.path)
        #expect(file.load())
        #expect(file.bextDescriptionC != nil)
        #expect(file.bextDescription != nil)

        let dictionary = file.infoDictionary
        Log.debug(dictionary)

        #expect(file[info: .product] == "This Is Spinal Tap")
        #expect(file[info: .artist] == "Spinal Tap")
        #expect(
            file[info: .comment]
                == "And oh how they danced. The little children of Stonehenge.Beneath the haunted moon.For fear that daybreak might come too soon."
        )
        #expect(file[info: .editedBy] == "SPFKMetadata")
        #expect(file[info: .title] == "Stonehenge")
        #expect(file[info: .bpm] == "666")
    }

    @Test func writeInfo() async throws {
        deleteBinOnExit = false
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())
        file[info: .bpm] = "667"
        file[info: .numColors] = "256"

        file.save()

        let newFile = WaveFileC(path: tmpfile.path)
        #expect(newFile.load())

        let newDict = newFile.infoDictionary
        Log.debug(newDict)

        #expect(newFile[info: .bpm] == "667")
        #expect(newFile[info: .numColors] == "256")
    }

    @Test func chunks() async throws {
        deleteBinOnExit = false

        let url = try copyToBin(url: TestBundleResources.shared.ixml_chunk)
        let file = WaveFileC(path: url.path)
        file.load()

        func dump(_ file: WaveFileC) {
            Log.debug("iXML:", file.iXML)
            Log.debug("infoDictionary:", file.infoDictionary)
            Log.debug("id3Dictionary:", file.id3Dictionary)
            Log.debug("bextDescription?.sequenceDescription:", file.bextDescriptionC?.sequenceDescription)
            Log.debug("markers:", file.markers.count, "marker(s)")
        }

        dump(file)

        file[info: .title] = "an info title"
        file[info: .lightness] = "Lightness"
        file[info: .numColors] = "256"

        file[id3: .title] = "an id3 title"
        file[id3: .remixer] = "an id3 remixer"

        file.iXML =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BWFXML><IXML_VERSION>1.4</IXML_VERSION><PROJECT>a new project</PROJECT></BWFXML>"
        file.bextDescriptionC?.sequenceDescription = "a new bext description"
        file.markers.append(
            AudioMarker(name: "new marker", time: 0, sampleRate: 44100, markerID: 0)
        )

        if let picture = TagPictureRef(
            url: TestBundleResources.shared.sharksandwich,
            pictureDescription: "new picture",
            pictureType: "jpeg"
        ) {
            file.tagPicture = TagPicture(picture: picture)
        }

        file.save()

        let updated = WaveFileC(path: url.path)
        updated.load()

        dump(updated)
    }
}
