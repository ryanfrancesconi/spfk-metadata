// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKImage
import SPFKTesting
import Testing
import UniformTypeIdentifiers

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite
class EmbeddedArtworkTests: BinTestCase {
    // MARK: - Read

    @Test(arguments: [TestBundleResources.shared.mp3_id3, TestBundleResources.shared.tabla_legacy_picture_flac])
    func readMatchesTagPictureRef(url: URL) throws {
        let pictureRef = try TagPictureRef.parsing(url: url)
        let artwork = try #require(try EmbeddedArtwork.read(from: url))

        #expect(artwork.cgImage.width == pictureRef.cgImage.width)
        #expect(artwork.cgImage.height == pictureRef.cgImage.height)
        #expect(artwork.utType == pictureRef.utType)
        #expect(artwork.pictureDescription == pictureRef.pictureDescription)
        #expect(artwork.pictureType == pictureRef.pictureType)
    }

    @Test(arguments: [TestBundleResources.shared.mp3_no_metadata, TestBundleResources.shared.toc_many_children])
    func readIsNilWithoutArtwork(url: URL) throws {
        #expect(try EmbeddedArtwork.read(from: url) == nil)
    }

    @Test func readThrowsForMissingFile() {
        let url = bin.appendingPathComponent("missing.mp3")

        #expect(throws: MetadataError.readFailed(.artwork, url)) {
            try EmbeddedArtwork.read(from: url)
        }
    }

    @Test func readThrowsForPictureThatDoesNotDecode() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)

        try ID3v24TagBuilder.replaceTag(in: url, with: [
            ID3v24TagBuilder.apic(mimeType: "image/jpeg", data: Data(repeating: 0xA5, count: 256)),
        ])

        #expect(TagPicture(path: url.path) == nil)

        #expect(throws: MetadataError.readFailed(.artwork, url)) {
            try EmbeddedArtwork.read(from: url)
        }
    }

    // MARK: - Write and remove

    @Test func writeThenReadRoundTrips() throws {
        deleteBinOnExit = true

        let pngURL = bin.appendingPathComponent("sharksandwich.png")
        let jpeg = try #require(EmbeddedArtwork(contentsOf: TestBundleResources.shared.sharksandwich))
        try jpeg.cgImage.export(utType: .png, to: pngURL)

        let sources: [(URL, UTType)] = [
            (TestBundleResources.shared.sharksandwich, .jpeg),
            (pngURL, .png),
            (TestBundleResources.shared.sharksandwich_webp, .jpeg),
        ]

        for (imageURL, storedType) in sources {
            let artwork = try #require(
                EmbeddedArtwork(contentsOf: imageURL, pictureDescription: "Cover", pictureType: "Front Cover")
            )

            for container in [TestBundleResources.shared.tabla_mp3, TestBundleResources.shared.tabla_flac] {
                let url = try copyToBin(url: container)
                try artwork.write(to: url)

                let readBack = try #require(try EmbeddedArtwork.read(from: url))
                #expect(readBack.cgImage.width == artwork.cgImage.width, "\(imageURL.lastPathComponent)")
                #expect(readBack.cgImage.height == artwork.cgImage.height, "\(imageURL.lastPathComponent)")
                #expect(readBack.utType == storedType, "\(imageURL.lastPathComponent) in \(url.lastPathComponent)")
                #expect(readBack.pictureDescription == "Cover")
                #expect(readBack.pictureType == "Front Cover")
            }
        }
    }

    @Test func readThenWriteCarriesEveryField() throws {
        deleteBinOnExit = true
        let artwork = try #require(try EmbeddedArtwork.read(from: TestBundleResources.shared.mp3_id3))
        let url = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        try artwork.write(to: url)

        let readBack = try #require(try EmbeddedArtwork.read(from: url))
        #expect(readBack.utType == artwork.utType)
        #expect(readBack.pictureDescription == artwork.pictureDescription)
        #expect(readBack.pictureType == artwork.pictureType)
    }

    @Test func imageFileThatDoesNotDecodeIsNil() throws {
        deleteBinOnExit = true
        let url = bin.appendingPathComponent("not-an-image.jpg")
        try Data(repeating: 0xA5, count: 256).write(to: url)

        #expect(EmbeddedArtwork(contentsOf: url) == nil)
    }

    @Test func writeToReadOnlyFileThrows() throws {
        deleteBinOnExit = true
        let artwork = try #require(EmbeddedArtwork(contentsOf: TestBundleResources.shared.sharksandwich))
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }

        #expect(throws: MetadataError.writeFailed(.artwork, url)) {
            try artwork.write(to: url)
        }
    }

    @Test func removeLeavesNoArtwork() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)
        #expect(try EmbeddedArtwork.read(from: url) != nil)

        try EmbeddedArtwork.remove(from: url)

        #expect(try EmbeddedArtwork.read(from: url) == nil)
    }

    @Test func removeFromMissingFileThrows() {
        let url = bin.appendingPathComponent("missing.mp3")

        #expect(throws: MetadataError.removeFailed(.artwork, url)) {
            try EmbeddedArtwork.remove(from: url)
        }
    }

    // MARK: - ArtworkDescription

    @Test(arguments: ["", "Cover"])
    func imageDescriptionMatchesPictureRefSetter(pictureDescription: String) throws {
        let source = try #require(try EmbeddedArtwork.read(from: TestBundleResources.shared.mp3_id3))
        var artwork = source
        artwork.pictureDescription = pictureDescription

        var viaSetter = ArtworkDescription()
        viaSetter.pictureRef = artwork.pictureRef

        let viaInit = ArtworkDescription(embeddedArtwork: artwork)

        #expect(viaInit.cgImage === viaSetter.cgImage)
        #expect(viaInit.description == viaSetter.description)
        #expect(viaInit.description == (pictureDescription.isEmpty ? nil : pictureDescription))
    }
}
