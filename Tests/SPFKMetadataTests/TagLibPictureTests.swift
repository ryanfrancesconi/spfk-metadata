// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import SPFKUtils
import Testing
import UniformTypeIdentifiers

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class TagLibPictureTests: BinTestCase {
    // MARK: - TagPictureRef.parsing

    @Test func parsingExtractsImageFromMP3() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let pictureRef = try TagPictureRef.parsing(url: url)

        #expect(pictureRef.cgImage.width == 600)
        #expect(pictureRef.cgImage.height == 592)
        #expect(pictureRef.utType == .jpeg)
    }

    @Test func parsingThrowsForFileWithoutArtwork() async throws {
        let url = TestBundleResources.shared.mp3_no_metadata

        #expect(throws: (any Error).self) {
            try TagPictureRef.parsing(url: url)
        }
    }

    @Test func parsingExportRoundtrip() async throws {
        deleteBinOnExit = true
        let url = TestBundleResources.shared.mp3_id3
        let pictureRef = try TagPictureRef.parsing(url: url)

        let ext = pictureRef.utType.preferredFilenameExtension ?? "jpg"
        let outputURL = bin.appendingPathComponent("artwork.\(ext)")
        try pictureRef.cgImage.export(utType: pictureRef.utType, to: outputURL)

        // Verify the exported file can be read back
        let data = try Data(contentsOf: outputURL)
        let reloaded = try CGImage.create(from: data)

        #expect(reloaded.width == pictureRef.cgImage.width)
        #expect(reloaded.height == pictureRef.cgImage.height)
    }

    // MARK: - TagPicture (low-level)

    @Test func getPicture() async throws {
        deleteBinOnExit = false

        let source = TestBundleResources.shared.mp3_id3

        let tagPicture = try #require(TagPicture(path: source.path)?.pictureRef)
        let desc = try #require(tagPicture.pictureDescription)
        let type = try #require(tagPicture.pictureType)
        let cgImage = tagPicture.cgImage

        #expect(cgImage.width == 600)
        #expect(cgImage.height == 592)
        #expect(type == "Front Cover")
        #expect(desc == "Smell the glove")

        // test export to file
        let exportType: UTType = .jpeg
        let filename = "\(type) - \(desc).\(exportType.preferredFilenameExtension ?? "jpeg")"
        let url = bin.appendingPathComponent(filename, conformingTo: exportType)
        try cgImage.export(utType: exportType, to: url)

        Log.debug(tagPicture.cgImage)
    }

    @Test func getPictureFail() async throws {
        let source = TestBundleResources.shared.toc_many_children
        #expect(source.exists)

        let tagPicture = TagPicture(path: source.path)?.pictureRef
        #expect(tagPicture == nil)
    }

    @Test(arguments: TestBundleResources.shared.markerFormats)
    func setPicture(url: URL) async throws {
        deleteBinOnExit = false

        let imageURL = TestBundleResources.shared.sharksandwich

        let pictureRef = try #require(
            TagPictureRef(
                url: imageURL,
                pictureDescription: "Shit Sandwich",
                pictureType: "Back Cover"
            )
        )

        #expect(pictureRef.utType == .jpeg)

        let tmpfile = try copyToBin(url: url)

        Log.debug(tmpfile.path)

        let result = TagPicture.write(pictureRef, path: tmpfile.path)
        #expect(result)

        // open the tmp file up and double check properties were correctly set
        let outputPicture = try #require(TagPicture(path: tmpfile.path)?.pictureRef)
        #expect(outputPicture.cgImage.width == pictureRef.cgImage.width)
        #expect(outputPicture.cgImage.height == pictureRef.cgImage.height)

        // not all formats support text description? mp4 / m4a
        // #expect(outputPicture.pictureDescription == "Shit Sandwich", "\(tmpfile.lastPathComponent)")
        // #expect(outputPicture.pictureType == "Back Cover", "\(tmpfile.lastPathComponent)")
    }
}
