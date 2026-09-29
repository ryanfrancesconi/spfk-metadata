// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import AVFoundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

@Suite(.tags(.file))
class AudioFileTypeTests: BinTestCase {
    @Test func tagFileType() throws {
        for item in TagFileTypeDef.allCases {
            #expect(AudioFileType(tagType: item) != nil)
        }
    }

    @Test func checkMissingExtension() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)
        let target = url.deletingPathExtension()
        try FileManager.default.moveItem(at: url, to: target)

        Log.debug(target)

        let type = AudioFileType(url: target)
        #expect(type == .m4a)
    }

    @Test func extensionlessNativeFLACIsDetectedByTagLib() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        let target = url.deletingPathExtension()
        try FileManager.default.moveItem(at: url, to: target)

        #expect(TagFileType.detect(target.path) == .flac)
        #expect(AudioFileType(url: target) == .flac)
    }

    @Test func utType() throws {
        let formats = TestBundleResources.shared.formats

        let audioFileTypes = formats.compactMap {
            AudioFileType(url: $0)
        }

        Log.debug(audioFileTypes)

        #expect(audioFileTypes.count == formats.count)

        let utTypes = audioFileTypes.compactMap { $0.utType }
        #expect(audioFileTypes.count == utTypes.count)

        Log.debug(utTypes)
    }
}
