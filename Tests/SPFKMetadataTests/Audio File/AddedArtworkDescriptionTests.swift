// Copyright Ryan Francesconi. All Rights Reserved.

import CoreGraphics
import Foundation
import SPFKBase
import SPFKImage
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

/// Artwork added to a file that had none is written without a picture description. A parse
/// without artwork holds the file's path in `artwork.description`, which must not reach
/// the file.
@Suite(.tags(.file))
final class AddedArtworkDescriptionTests: BinTestCase {
    private func addArtwork(to fixture: URL) async throws -> URL {
        let url = try copyToBin(url: fixture)
        var description = try await MetaAudioFileDescription(parsing: url)
        try #require(description.artwork.cgImage == nil)

        let cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
        await description.artwork.update(cgImage: cgImage)
        try description.save(dirtyFlags: [.artwork])
        return url
    }

    @Test func wavAPICCarriesNoPath() async throws {
        let url = try await addArtwork(to: TestBundleResources.shared.tabla_wav)

        let payload = try #require(try IFFChunks.payload(id: "ID3 ", in: url, bigEndian: false))
        let tag = try #require(try ID3v2Frames.tag(in: payload))
        let pictures = try tag.frames("APIC").map { try ID3v2Frames.Picture($0.body) }

        #expect(pictures.count == 1)
        for picture in pictures {
            #expect(!picture.description.contains(url.path), "\(picture.description)")
        }
    }

    @Test func flacPictureCarriesNoPath() async throws {
        let url = try await addArtwork(to: TestBundleResources.shared.tabla_flac)
        let descriptions = try flacPictureDescriptions(in: url)

        #expect(descriptions.count == 1)
        for description in descriptions {
            #expect(!description.contains(url.path), "\(description)")
        }
    }

    /// Each native PICTURE block's description, read from the file's bytes.
    private func flacPictureDescriptions(in url: URL) throws -> [String] {
        let bytes = [UInt8](try Data(contentsOf: url))
        try #require(bytes.starts(with: Array("fLaC".utf8)))

        func uint32(_ at: Int) -> Int {
            Int(bytes[at]) << 24 | Int(bytes[at + 1]) << 16 | Int(bytes[at + 2]) << 8 | Int(bytes[at + 3])
        }

        var descriptions: [String] = []
        var offset = 4
        var isLast = false

        while !isLast, offset + 4 <= bytes.count {
            isLast = bytes[offset] & 0x80 != 0
            let type = bytes[offset] & 0x7F
            let length = Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            let body = offset + 4

            // PICTURE: picture type, MIME length + MIME, description length + UTF-8 description.
            if type == 6 {
                let mimeLength = uint32(body + 4)
                let descriptionAt = body + 8 + mimeLength
                let descriptionLength = uint32(descriptionAt)
                let start = descriptionAt + 4
                descriptions.append(String(decoding: bytes[start ..< start + descriptionLength], as: UTF8.self))
            }

            offset = body + length
        }

        return descriptions
    }
}
