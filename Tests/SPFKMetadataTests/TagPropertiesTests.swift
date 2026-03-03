// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class TagPropertiesTests: BinTestCase {
    @available(macOS 12, iOS 16, *)
    @Test func benchmarkTagLib() async throws {
        let tagLibElapsed = try ContinuousClock().measure {
            _ = try TagProperties(url: TestBundleResources.shared.mp3_id3)
        }

        let avElapsed = try await ContinuousClock().measure {
            _ = try await TagPropertiesAV(url: TestBundleResources.shared.mp3_id3)
        }

        Log.debug("TagLib took", tagLibElapsed)
        Log.debug("AV took", avElapsed)
    }

    @Test func parseID3MP3() async throws {
        let properties = try TagProperties(url: TestBundleResources.shared.mp3_id3)
        verify(properties: properties.data)
    }

    @Test func parseID3MP3_AV() async throws {
        let properties = try await TagPropertiesAV(url: TestBundleResources.shared.mp3_id3)
        // verify(properties: properties)

        Log.debug(properties.data)
    }

    @Test func parseID3Wave() async throws {
        Log.debug(TestBundleResources.shared.wav_bext_v2.path)

        let properties = try TagProperties(url: TestBundleResources.shared.wav_bext_v2)
        verify(properties: properties.data)
    }

    @Test func readWriteTagProperties() async throws {
        deleteBinOnExit = false

        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        // source
        let sourcefile = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        let source = try TagProperties(url: sourcefile)

        // target
        var output = try TagProperties(url: tmpfile)
        try output.removeAllAndSave(to: tmpfile)

        #expect(output.tags.isEmpty)

        // replace all tags
        output.tags = source.tags
        try output.save(to: tmpfile)

        #expect(output.tags.count == 28)

        let random = Float.random(in: Float.unitIntervalRange)
        output[.title] = "New Title \(random)"
        output[.keywords] = "Keywords!"
        try output.save(to: tmpfile)

        try output.load(url: tmpfile)
        #expect(output[.title] == "New Title \(random)")
        #expect(output[.keywords] == "Keywords!")
    }

    @Test(arguments: TestBundleResources.shared.markerFormats)
    func readFormats(url: URL) async throws {
        let source = try TagProperties(url: TestBundleResources.shared.mp3_id3)

        Log.debug("Parsing", url.lastPathComponent)
        let props = try TagProperties(url: url)
        #expect(props.tags == source.tags)
    }

    @Test func writeFormats() async throws {
        deleteBinOnExit = false

        let source = try TagProperties(url: TestBundleResources.shared.mp3_id3)

        let files = TestBundleResources.shared.formats

        for file in files {
            let copy = try copyToBin(url: file)

            do {
                var copyProps = try TagProperties(url: copy)

                try copyProps.removeAllAndSave(to: copy)
                copyProps.tags = source.tags
                try copyProps.save(to: copy)
                try copyProps.load(url: copy)
                Log.debug(copy.lastPathComponent, copyProps.description)

                #expect(copyProps.tags == source.tags)

            } catch {
                Log.error(error)
            }
        }
    }

    @Test func stripTags() async throws {
        deleteBinOnExit = false

        let files = TestBundleResources.shared.formats

        for file in files {
            let copy = try copyToBin(url: file)

            do {
                var copyProps = try TagProperties(url: copy)
                try copyProps.removeAllAndSave(to: copy)
                try copyProps.load(url: copy)

                Log.debug(copy.lastPathComponent, copyProps.description)

                #expect(copyProps.tags == [:])

            } catch {
                Log.error(error)
            }
        }
    }

    @Test func customTag() async throws {
        deleteBinOnExit = false
        let tmpfile = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        var dict: [String: String] = TagLibBridge.getProperties(tmpfile.path) as? [String: String] ?? [:]

        dict["loudnessValue"] = "-9"
        dict["loudnessRange"] = "-10"
        dict["maxTruePeakLevel"] = "-16"

        TagLibBridge.setProperties(tmpfile.path, dictionary: dict)

        let newFile = try TagProperties(url: tmpfile)
        Log.debug(newFile.customTags)

        let id3File = ID3File(path: tmpfile.path)
        id3File.load()

        Log.debug(id3File.dictionary)
    }

    @Test func audioProperties() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let file = try TagProperties(url: url)

        let audioProperties = try #require(file.audioProperties)

        #expect(audioProperties.sampleRate == 44100)
        #expect(audioProperties.bitRate == 129) // should be 128, taglib reports 129
        #expect(audioProperties.channelCount == 2)
        #expect(audioProperties.duration == 2.978)
    }
}

extension TagPropertiesTests {
    private func verify(properties: TagPropertiesContainerModel) {
        Log.debug(properties.description)

        #expect(properties.contains(key: .album))
        #expect(properties.contains(key: .albumArtist))
        #expect(properties.contains(key: .remixer))
        #expect(properties.contains(key: .artist))
        #expect(properties.contains(key: .bpm))
        #expect(properties.contains(key: .comment))
        #expect(properties.contains(key: .composer))
        #expect(properties.contains(key: .copyright))
        #expect(properties.contains(key: .date))
        #expect(properties.contains(key: .genre))
        #expect(properties.contains(key: .initialKey))
        #expect(properties.contains(key: .isrc))
        #expect(properties.contains(key: .label))
        #expect(properties.contains(key: .language))
        #expect(properties.contains(key: .lyricist))
        #expect(properties.contains(key: .lyrics))
        #expect(properties.contains(key: .mood))
        #expect(properties.contains(key: .releaseCountry))
        #expect(properties.contains(key: .subtitle))
        #expect(properties.contains(key: .title))
        #expect(properties.contains(key: .trackNumber))

        let tags = properties.tags

        #expect(tags[.album] == "This Is Spinal Tap")
        #expect(tags[.albumArtist] == "Spinal Tap")
        #expect(tags[.remixer] == "SPFKMetadata")
        #expect(tags[.title] == "Stonehenge")
        #expect(tags[.bpm] == "666")
    }
}
