// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AEXML
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A save writes `bext` and iXML only when its own model of them changed, and an edited `bext`
/// keeps the bytes `BEXTDescription` does not model.
@Suite(.tags(.file))
final class ProductionChunkOwnershipTests: BinTestCase {
    enum Writer: String, CaseIterable, CustomTestStringConvertible {
        case titleSave
        case ratingSave
        case markerSave
        case artworkSave
        case bextSave
        case iXMLSave
        case iXMLCommentSave
        case normalizedIXMLTitleSave
        case productionBEXTWrite
        case productionIXMLWrite

        var testDescription: String { rawValue }

        var writesBEXT: Bool { [.bextSave, .productionBEXTWrite].contains(self) }
        var writesIXML: Bool { [.iXMLSave, .iXMLCommentSave, .productionIXMLWrite].contains(self) }
    }

    static let editedTitle = "Ownership Edited"
    static let editedProject = "Ownership Project Edited"
    static let editedDescription = "Ownership BEXT Edited"
    static let comment = "<!-- Written by another recorder -->\n"

    /// As another recorder writes it: a comment, a CDATA section and a trailing line break, none of
    /// which survive a parse and re-serialization.
    static let iXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <BWFXML>
    <!-- Written by another recorder -->
    <IXML_VERSION>1.61</IXML_VERSION>
    <PROJECT>Ownership Project</PROJECT>
    <USER><![CDATA[Scene 12 <take 3>]]></USER>
    </BWFXML>\r\n
    """

    /// The safety net's version 2 `bext` with a pattern in the reserved bytes and NUL padding after
    /// the coding history.
    static var bext: Data {
        var data = SafetyNetRIFFForeign.broadcastExtension
        data.replaceSubrange(422 ..< 602, with: Data((0 ..< 180).map { UInt8(truncatingIfNeeded: $0 * 3 + 1) }))
        return data + Data(count: 6)
    }

    // MARK: - WAV

    @Test(arguments: Writer.allCases)
    func waveChunksAreWrittenOnlyWhenTheirModelChanged(writer: Writer) async throws {
        let url = try waveFixture()
        let before = try RIFFChunks(contentsOf: url)

        try await write(writer, to: url, fileType: .wav)

        let after = try RIFFChunks(contentsOf: url)

        if !writer.writesBEXT {
            #expect(after.first("bext")?.payload == before.first("bext")?.payload)
            #expect(offset(of: "bext", in: after) == offset(of: "bext", in: before))
        }

        if !writer.writesIXML {
            #expect(after.first("iXML")?.payload == before.first("iXML")?.payload)
            #expect(offset(of: "iXML", in: after) == offset(of: "iXML", in: before))
        }
    }

    @Test(arguments: [Writer.bextSave, .productionBEXTWrite])
    func waveBEXTEditKeepsUnmodeledBytes(writer: Writer) async throws {
        let url = try waveFixture()

        try await write(writer, to: url, fileType: .wav)

        let payload = try #require(RIFFChunks(contentsOf: url).first("bext")?.payload)
        try expectUnmodeledBytesKept(in: payload)
    }

    @Test(arguments: [AudioFileType.wav, .flac])
    func commentOnlyIXMLEditIsWritten(fileType: AudioFileType) async throws {
        let url = try fileType == .wav ? waveFixture() : flacFixture()

        try await write(.iXMLCommentSave, to: url, fileType: fileType)

        #expect(ProductionChunks.readIXML(from: url, fileType: fileType) == Self.iXML.replacingOccurrences(of: Self.comment, with: ""))
    }

    @Test func waveParseHoldsIXMLAsStored() async throws {
        let url = try waveFixture()
        let description = try await MetaAudioFileDescription(parsing: url)
        #expect(description.iXMLMetadata == Self.iXML)
    }

    // MARK: - FLAC

    @Test(arguments: [Writer.titleSave, .markerSave, .artworkSave, .bextSave, .normalizedIXMLTitleSave, .productionBEXTWrite])
    func flacIXMLIsKeptAsStoredWhenUnedited(writer: Writer) async throws {
        let url = try flacFixture()

        try await write(writer, to: url, fileType: .flac)

        #expect(ProductionChunks.readIXML(from: url, fileType: .flac) == Self.iXML)
    }

    @Test(arguments: [Writer.bextSave, .productionBEXTWrite])
    func flacBEXTEditKeepsUnmodeledBytes(writer: Writer) async throws {
        let url = try flacFixture()

        try await write(writer, to: url, fileType: .flac)

        let chunk = try FLACBlocks(contentsOf: url).blocks.compactMap { try $0.riffChunk() }.first { $0.id == "bext" }
        try expectUnmodeledBytesKept(in: try #require(chunk?.payload))
    }

    @Test func flacIXMLEditIsWrittenAndBEXTKept() async throws {
        let url = try flacFixture()
        let bext = try #require(FLACBlocks(contentsOf: url).blocks.compactMap { try $0.riffChunk() }.first { $0.id == "bext" })

        try await write(.iXMLSave, to: url, fileType: .flac)

        #expect(ProductionChunks.readIXML(from: url, fileType: .flac) == Self.iXML.replacingOccurrences(of: "Ownership Project", with: Self.editedProject))
        let after = try FLACBlocks(contentsOf: url).blocks.compactMap { try $0.riffChunk() }.first { $0.id == "bext" }
        #expect(after?.payload == bext.payload)
    }

    // MARK: - Helpers

    private func expectUnmodeledBytesKept(in payload: Data, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let original = Self.bext
        #expect(try RIFFChunks.BroadcastExtension(payload).description == Self.editedDescription, sourceLocation: sourceLocation)
        #expect(payload.dropFirst(422).prefix(180) == original.dropFirst(422).prefix(180), "reserved", sourceLocation: sourceLocation)
        #expect(payload.dropFirst(602) == original.dropFirst(602), "coding history and its padding", sourceLocation: sourceLocation)
    }

    private func write(_ writer: Writer, to url: URL, fileType: AudioFileType) async throws {
        switch writer {
        case .titleSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.editedTitle
            try description.save(dirtyFlags: [.metadata])

        case .ratingSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.rating] = "4"
            try description.save(dirtyFlags: [.metadata])

        case .markerSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: SafetyNetEdit.markers)
            try description.save(dirtyFlags: [.markers])

        case .artworkSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.imageDescription.pictureRef = try SafetyNetSetup.picture(TestBundleResources.shared.songbird)
            try description.save(dirtyFlags: [.image])

        case .bextSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            var bext = try #require(description.bextDescription)
            bext.sequenceDescription = Self.editedDescription
            description.bextDescription = bext
            try description.save(dirtyFlags: [.metadata])

        case .iXMLSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.iXMLMetadata = try #require(description.iXMLMetadata).replacingOccurrences(of: "Ownership Project", with: Self.editedProject)
            try description.save(dirtyFlags: [.metadata])

        case .iXMLCommentSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.iXMLMetadata = try #require(description.iXMLMetadata).replacingOccurrences(of: Self.comment, with: "")
            try description.save(dirtyFlags: [.metadata])

        case .normalizedIXMLTitleSave:
            // As a library row persisted before the parse kept iXML as stored holds it.
            var description = try await MetaAudioFileDescription(parsing: url)
            var options = AEXMLOptions()
            options.parserSettings.shouldTrimWhitespace = false
            description.iXMLMetadata = try AEXMLDocument(xml: Self.iXML, options: options).xml
            description.tagProperties[.title] = Self.editedTitle
            try description.save(dirtyFlags: [.metadata])

        case .productionBEXTWrite:
            var bext = try #require(ProductionChunks.readBEXT(from: url, fileType: fileType))
            bext.sequenceDescription = Self.editedDescription
            try ProductionChunks.writeBEXT(bext, to: url, fileType: fileType)

        case .productionIXMLWrite:
            try ProductionChunks.writeIXML(Self.iXML.replacingOccurrences(of: "Ownership Project", with: Self.editedProject), to: url, fileType: fileType)
        }
    }

    private func offset(of id: String, in riff: RIFFChunks) -> Int? {
        var offset = 12
        for chunk in riff.chunks {
            if chunk.id == id { return offset }
            offset += 8 + chunk.payload.count + chunk.payload.count % 2
        }
        return nil
    }

    /// `tabla.wav` with the fixture's `bext` and iXML ahead of `data`, as a recorder writes them.
    private func waveFixture() throws -> URL {
        let url = bin.appendingPathComponent("ownership.wav")
        try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_wav, to: url)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.insert(contentsOf: [
                RIFFChunks.Chunk(id: "bext", payload: Self.bext),
                RIFFChunks.Chunk(id: "iXML", payload: Data(Self.iXML.utf8)),
            ], at: 1)
        }

        return url
    }

    /// `tabla.flac` with the fixture's `bext` and iXML in `riff` APPLICATION blocks.
    private func flacFixture() throws -> URL {
        let url = bin.appendingPathComponent("ownership.flac")
        try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_flac, to: url)

        try FLACBlockWriter.rewrite(url) { blocks in
            blocks.append(FLACBlockWriter.riff(id: "bext", payload: Self.bext))
            blocks.append(FLACBlockWriter.riff(id: "iXML", payload: Data(Self.iXML.utf8)))
        }

        return url
    }
}
