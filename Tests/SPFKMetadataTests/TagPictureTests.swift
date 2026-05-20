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
class TagPictureTests: BinTestCase {
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

    @Test func removePicture() async throws {
        deleteBinOnExit = true
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_id3)

        // Verify initial artwork exists
        #expect(TagPicture(path: tmpfile.path)?.pictureRef != nil)

        // Remove it
        #expect(TagPicture.write(nil, path: tmpfile.path))

        // Verify it's gone
        #expect(TagPicture(path: tmpfile.path)?.pictureRef == nil)
    }

    @Test(arguments: TestBundleResources.shared.markerFormats)
    func removePictureRoundtrip(url: URL) async throws {
        deleteBinOnExit = true
        let imageURL = TestBundleResources.shared.sharksandwich
        let pictureRef = try #require(TagPictureRef(url: imageURL, pictureDescription: "Test", pictureType: "Front Cover"))
        let tmpfile = try copyToBin(url: url)

        // Write artwork
        #expect(TagPicture.write(pictureRef, path: tmpfile.path))
        #expect(TagPicture(path: tmpfile.path)?.pictureRef != nil)

        // Remove artwork
        #expect(TagPicture.write(nil, path: tmpfile.path))
        #expect(TagPicture(path: tmpfile.path)?.pictureRef == nil)
    }

    // MARK: - FLAC native PICTURE block round-trip

    @Test func flacNativePictureBlockRoundtrip() async throws {
        // Synthesized 2026-05-20: artwork written via FileRef::setComplexProperties
        // (new path-based code), which stores a native FLAC PICTURE block.
        deleteBinOnExit = true

        let source = TestBundleResources.shared.tabla_flac
        let imageURL = TestBundleResources.shared.sharksandwich

        let pictureRef = try #require(
            TagPictureRef(url: imageURL, pictureDescription: "Front Cover", pictureType: "Front Cover")
        )
        let tmpFile = try copyToBin(url: source)

        // Write via path-based API — routes through FileRef::setComplexProperties
        #expect(TagPicture.write(pictureRef, path: tmpFile.path))

        // Read back via path-based API — should find the native PICTURE block
        let readBack = try #require(TagPicture(path: tmpFile.path)?.pictureRef)
        #expect(readBack.cgImage.width == pictureRef.cgImage.width)
        #expect(readBack.cgImage.height == pictureRef.cgImage.height)

        // FileRef::setComplexProperties must not write a METADATA_BLOCK_PICTURE Vorbis comment
        let fileData = try Data(contentsOf: tmpFile)
        let mbpMarker = Data("METADATA_BLOCK_PICTURE=".utf8)
        #expect(fileData.range(of: mbpMarker) == nil)
    }

    // MARK: - Legacy XiphComment FLAC migration

    @Test func flacLegacyXiphCommentMigration() async throws {
        // Fixture generated 2026-05-20 with make_legacy_flac.py: tabla.flac base
        // with sharksandwich.jpg embedded as a METADATA_BLOCK_PICTURE Vorbis
        // comment entry; no native FLAC PICTURE block is present.
        deleteBinOnExit = true

        let source = TestBundleResources.shared.tabla_legacy_picture_flac
        let imageURL = TestBundleResources.shared.sharksandwich

        // Read fallback: picture lives in XiphComment, not native block
        let initial = try #require(TagPicture(path: source.path)?.pictureRef)
        #expect(initial.cgImage.width > 0)
        #expect(initial.cgImage.height > 0)

        let tmpFile = try copyToBin(url: source)

        // Write a picture — triggers migration: native block written, XiphComment stripped
        let newPicture = try #require(
            TagPictureRef(url: imageURL, pictureDescription: "Test", pictureType: "Front Cover")
        )
        #expect(TagPicture.write(newPicture, path: tmpFile.path))

        // Re-read — artwork must still be present (now via native PICTURE block)
        let readBack = try #require(TagPicture(path: tmpFile.path)?.pictureRef)
        #expect(readBack.cgImage.width > 0)
        #expect(readBack.cgImage.height > 0)

        // Vorbis comment METADATA_BLOCK_PICTURE entry must be gone
        let fileData = try Data(contentsOf: tmpFile)
        let mbpMarker = Data("METADATA_BLOCK_PICTURE=".utf8)
        #expect(fileData.range(of: mbpMarker) == nil)
    }

    @Test func flacLegacyXiphCommentRemove() async throws {
        // Verifies that write(nil) on a legacy XiphComment-only FLAC clears the
        // pictureList (via removeAllPictures), not just fieldListMap.
        deleteBinOnExit = true

        let source = TestBundleResources.shared.tabla_legacy_picture_flac
        let tmpFile = try copyToBin(url: source)

        // Confirm artwork is present before removal
        #expect(TagPicture(path: tmpFile.path)?.pictureRef != nil)

        // Remove without a prior write — exercises clearLegacyFlacXiphCommentPictures directly
        #expect(TagPicture.write(nil, path: tmpFile.path))

        // Artwork gone
        #expect(TagPicture(path: tmpFile.path)?.pictureRef == nil)

        // No METADATA_BLOCK_PICTURE= bytes remain in the file
        let fileData = try Data(contentsOf: tmpFile)
        let mbpMarker = Data("METADATA_BLOCK_PICTURE=".utf8)
        #expect(fileData.range(of: mbpMarker) == nil)
    }

    // MARK: - Non-JPEG/PNG artwork decode

    @Test(arguments: [
        TestBundleResources.shared.sharksandwich_heic,
        TestBundleResources.shared.sharksandwich_webp,
    ])
    func alternateFormatArtworkDecode(imageURL: URL) async throws {
        // Verifies the CGImageSource path handles formats beyond JPEG and PNG.
        deleteBinOnExit = true

        // Load image via TagPictureRef — exercises CGImageSource decode path in initWithURL:
        let imageRef = try #require(
            TagPictureRef(url: imageURL, pictureDescription: "cover", pictureType: "Front Cover")
        )
        #expect(imageRef.cgImage.width > 0)
        #expect(imageRef.cgImage.height > 0)

        // Embed in a FLAC copy and read back — exercises CGImageSource decode in buildPictureRef
        let tmpFile = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        #expect(TagPicture.write(imageRef, path: tmpFile.path))

        let readBack = try #require(TagPicture(path: tmpFile.path)?.pictureRef)
        #expect(readBack.cgImage.width == imageRef.cgImage.width)
        #expect(readBack.cgImage.height == imageRef.cgImage.height)
    }

    // MARK: - Tag-based API (via WaveFileC)

    @Test func artworkWriteAndReadViaWaveFileC() async throws {
        deleteBinOnExit = true
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        let pictureRef = try #require(
            TagPictureRef(
                url: TestBundleResources.shared.sharksandwich,
                pictureDescription: "Test Artwork",
                pictureType: "Front Cover"
            )
        )

        let file = WaveFileC(path: tmpfile.path)
        #expect(file.load())
        file.tagPicture = TagPicture(picture: pictureRef)
        file.imageNeedsSave = true
        file.markersNeedsSave = false
        #expect(file.save())

        let reloaded = WaveFileC(path: tmpfile.path)
        #expect(reloaded.load())
        let readPicture = try #require(reloaded.tagPicture?.pictureRef)

        #expect(readPicture.cgImage.width == pictureRef.cgImage.width)
        #expect(readPicture.cgImage.height == pictureRef.cgImage.height)
        #expect(readPicture.pictureDescription == "Test Artwork")
        #expect(readPicture.pictureType == "Front Cover")
    }

    @Test func artworkClearViaWaveFileC() async throws {
        deleteBinOnExit = true
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        let pictureRef = try #require(
            TagPictureRef(
                url: TestBundleResources.shared.sharksandwich,
                pictureDescription: "To Be Removed",
                pictureType: "Front Cover"
            )
        )

        let file1 = WaveFileC(path: tmpfile.path)
        #expect(file1.load())
        file1.tagPicture = TagPicture(picture: pictureRef)
        file1.imageNeedsSave = true
        file1.markersNeedsSave = false
        #expect(file1.save())

        let file2 = WaveFileC(path: tmpfile.path)
        #expect(file2.load())
        #expect(file2.tagPicture?.pictureRef != nil)

        file2.tagPicture = nil
        file2.imageNeedsSave = true
        file2.markersNeedsSave = false
        #expect(file2.save())

        let file3 = WaveFileC(path: tmpfile.path)
        #expect(file3.load())
        #expect(file3.tagPicture?.pictureRef == nil)
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

    // MARK: - Development

    @Test(arguments: [
        "/Volumes/ADD2/ADD/TEMP/Foley-Flac/Foley/Element/Bottles And Cups/Bottle Open/Bottle Top Open 01.flac",
        "/Volumes/ADD2/ADD/TEMP/Foley-Flac/Foley/Element/Bottles And Cups/Bottle Open/Bottle Top Open 02.flac",
    ])
    func devVerifyEmbeddedArtworkInFoleyFlac(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        guard url.exists else { return }

        let picture = try #require(TagPicture(path: path)?.pictureRef)

        Log.debug("[\(url.lastPathComponent)] \(picture.cgImage.width)x\(picture.cgImage.height) utType=\(picture.utType.identifier) mimeType=\(picture.utType.preferredMIMEType ?? "?")")

        #expect(picture.cgImage.width > 0)
        #expect(picture.cgImage.height > 0)
    }
}
