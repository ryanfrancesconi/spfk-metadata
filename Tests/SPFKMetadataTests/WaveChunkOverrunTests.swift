// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A chunk running past the end of a WAV: an APEv2 tag appended after the chunks, whose `APETAGEX`
/// reads as a chunk ID with a size far past the end, or an audio chunk declaring more than the file
/// holds. Nothing a save writes may end up read as part of either.
@Suite(.tags(.file))
final class WaveChunkOverrunTests: BinTestCase {
    /// An APEv2 tag with a header, one `Title` item and a footer, as TagLib and most taggers write it.
    private static let apeTag: Data = {
        func le32(_ value: Int) -> Data { withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) } }

        let value = Data("ape title".utf8)
        let item = le32(value.count) + le32(0) + Data("Title".utf8) + Data([0]) + value
        let size = item.count + 32

        func header(flags: UInt32) -> Data {
            Data("APETAGEX".utf8) + le32(2000) + le32(size) + le32(1) + le32(Int(flags)) + Data(count: 8)
        }
        return header(flags: 0xA000_0000) + item + header(flags: 0x8000_0000)
    }()

    private func fixture() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Self.apeTag)
        try handle.close()
        return url
    }

    private func infoArtist(in url: URL) throws -> String? {
        let file = WaveFileC(path: url.path)
        try #require(file.load())
        return file.infoDictionary["IART"] as? String
    }

    @Test func titleSaveKeepsTheINFOTagAndTheTrailingAPETag() async throws {
        let url = try fixture()
        let artist = try #require(try infoArtist(in: url))

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "After"
        try description.save(dirtyFlags: [.tags])

        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "After")
        #expect(try infoArtist(in: url) == artist)
        #expect(try Data(contentsOf: url).suffix(Self.apeTag.count) == Self.apeTag)
    }

    /// A last `data` chunk declaring more bytes than the file holds is read up to the end of the file;
    /// the chunks a save appends after it must not be read as part of it next time.
    @Test func titleSaveAfterAnOversizedLastDataChunkIsReadBack() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks = chunks.filter { $0.id == "fmt " || $0.id == "data" }
        }

        var data = try Data(contentsOf: url)
        let sizeField = try #require(data.range(of: Data("data".utf8))).upperBound
        let declared = data[sizeField ..< sizeField + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        data.replaceSubrange(sizeField ..< sizeField + 4, with: RIFFChunkBuilder.le32(Int(declared) + 100))
        try data.write(to: url)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "After"
        try description.save(dirtyFlags: [.tags])

        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "After")
    }
}
