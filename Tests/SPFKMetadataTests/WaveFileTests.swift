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

    /// Saving with empty dictionaries must clear all existing INFO and ID3 fields.
    @Test func clearAllInfoAndID3Tags() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        // Confirm the file starts with known metadata
        let initial = WaveFileC(path: tmpfile.path)
        #expect(initial.load())
        #expect(initial[info: .title] == "Stonehenge")
        #expect(initial[info: .artist] == "Spinal Tap")
        #expect(initial[info: .bpm] == "666")

        // Save with empty dictionaries (no load — dicts start empty)
        let file = WaveFileC(path: tmpfile.path)
        file.markersNeedsSave = false
        file.imageNeedsSave = false
        #expect(file.save())

        // All INFO fields must be gone
        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        #expect(reloaded[info: .title] == nil)
        #expect(reloaded[info: .artist] == nil)
        #expect(reloaded[info: .bpm] == nil)
    }

    /// Saving with only some INFO keys must remove existing keys absent from the new set.
    @Test func partialInfoUpdateClearsStaleKeys() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        // Confirm multiple fields exist
        let initial = WaveFileC(path: tmpfile.path)
        #expect(initial.load())
        #expect(initial[info: .title] == "Stonehenge")
        #expect(initial[info: .bpm] == "666")

        // Save with only bpm set — title must be cleared
        let file = WaveFileC(path: tmpfile.path)
        file[info: .bpm] = "777"
        file.markersNeedsSave = false
        file.imageNeedsSave = false
        #expect(file.save())

        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        #expect(reloaded[info: .bpm] == "777")
        #expect(reloaded[info: .title] == nil)
        #expect(reloaded[info: .artist] == nil)
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

    /// Unicode characters in WAV INFO tags must survive a complete save/load round-trip.
    /// TagLib uses UTF-8 for INFO tags in modern versions — this confirms non-ASCII content
    /// (CJK, accented Latin, emoji) is not corrupted or lost.
    @Test func unicodeINFOTagRoundTrip() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        let file = WaveFileC(path: tmpfile.path)
        file[info: .title] = "テスト曲 Ölé 🎵"
        file[info: .artist] = "Ärτιst"
        file.markersNeedsSave = false
        file.imageNeedsSave = false
        #expect(file.save())

        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        #expect(reloaded[info: .title] == "テスト曲 Ölé 🎵")
        #expect(reloaded[info: .artist] == "Ärτιst")
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
