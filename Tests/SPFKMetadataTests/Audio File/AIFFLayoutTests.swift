// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import CoreGraphics
import Foundation
import SPFKBase
import SPFKImage
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A tag or artwork save leaves an AIFF's `SSND` where it was, on a file whose `ID3 ` chunk
/// precedes it. Markers are written by Core Audio, which rewrites the file, so they are not covered.
@Suite(.tags(.file))
final class AIFFLayoutTests: BinTestCase {
    enum Writer: String, CaseIterable, CustomTestStringConvertible {
        case titleSave
        case artworkSave
        case titleAndArtworkSave
        case tagPropertiesSave

        var testDescription: String { rawValue }
    }

    /// Longer than the padding TagLib renders into an ID3v2 tag, so the chunk grows.
    private static let longTitle = String(repeating: "AIFF layout ", count: 400)

    @Test(arguments: Writer.allCases)
    func aSaveLeavesTheSoundDataInPlace(writer: Writer) async throws {
        let url = try leadingID3Fixture()
        let before = try Self.soundChunk(in: url)

        switch writer {
        case .titleSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.longTitle
            try description.save(dirtyFlags: [.metadata])
        case .artworkSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.imageDescription.cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
            try description.save(dirtyFlags: [.image])
        case .titleAndArtworkSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.longTitle
            description.imageDescription.cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
            try description.save(dirtyFlags: [.metadata, .image])
        case .tagPropertiesSave:
            var properties = try TagProperties(url: url)
            properties[.title] = Self.longTitle
            try properties.save(to: url)
        }

        let after = try Self.soundChunk(in: url)
        #expect(after.offset == before.offset)
        #expect(after.payload == before.payload)

        let reread = try await MetaAudioFileDescription(parsing: url)
        if writer != .artworkSave {
            #expect(reread.tagProperties[.title] == Self.longTitle)
        }
        if writer == .artworkSave || writer == .titleAndArtworkSave {
            #expect(reread.imageDescription.cgImage != nil)
        }

        let original = try AVAudioFile(forReading: TestBundleResources.shared.tabla_aif)
        #expect(try AVAudioFile(forReading: url).length == original.length)
    }

    /// `tabla.aif` with its `ID3 ` chunk moved ahead of `SSND`.
    private func leadingID3Fixture() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)

        try AIFFChunkBuilder.rewrite(url) { chunks in
            let id3 = try #require(chunks.firstIndex { $0.id == "ID3 " })
            let tag = chunks.remove(at: id3)
            let sound = try #require(chunks.firstIndex { $0.id == "SSND" })
            chunks.insert(tag, at: sound)
        }

        return url
    }

    /// The `SSND` chunk's header offset and payload, from a walk of the file's own chunk list.
    private static func soundChunk(in url: URL) throws -> (offset: Int, payload: Data) {
        let data = try Data(contentsOf: url)
        var offset = 12

        while offset + 8 <= data.count {
            let id = String(decoding: data[offset ..< offset + 4], as: UTF8.self)
            let size = data[offset + 4 ..< offset + 8].reduce(0) { $0 << 8 | Int($1) }

            if id == "SSND" {
                return (offset, data.subdata(in: offset + 8 ..< offset + 8 + size))
            }

            offset += 8 + size + (size & 1)
        }

        throw CocoaError(.fileReadCorruptFile)
    }
}
