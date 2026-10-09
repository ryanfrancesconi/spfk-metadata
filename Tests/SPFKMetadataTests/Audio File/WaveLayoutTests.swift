// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreGraphics
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Every WAV writer leaves the audio where it was, on a file whose metadata precedes `data` as a
/// field recorder writes it.
@Suite
final class WaveLayoutTests: BinTestCase {
    enum Form: String, CaseIterable, CustomTestStringConvertible {
        case riff = "RIFF"
        case rf64 = "RF64"

        var testDescription: String { rawValue }
    }

    enum Writer: String, CaseIterable, CustomTestStringConvertible {
        case titleSave
        case markerSave
        case artworkSave
        case bextSave
        case packetReplace
        case packetRemove
        case tagPropertiesSave
        case artworkWrite
        case artworkRemove
        case markersWrite
        case markersRemove
        case productionBEXTWrite
        case productionIXMLWrite
        case productionChunksRemove
        case bextDescriptionWrite
        case ratingWrite

        var testDescription: String { rawValue }
    }

    static let editedTitle = "Layout Edited"
    static let editedProject = "Layout Project Edited"

    @Test(arguments: Writer.allCases, Form.allCases)
    func audioStaysInPlace(writer: Writer, form: Form) async throws {
        let url = try recorderFixture(form: form)
        let before = try Layout(url: url)

        try await write(writer, to: url)

        let after = try Layout(url: url)
        #expect(after.dataOffset == before.dataOffset)
        #expect(after.data == before.data)
        #expect(after.storedSize == after.walkedSize)
        try await expectWritten(writer, in: url)
    }

    /// A chunk that grows once is given room, so growing it again rewrites it where it is.
    @Test(arguments: Form.allCases)
    func secondGrowthFitsInPlace(form: Form) async throws {
        let url = try recorderFixture(form: form)

        try ProductionChunks.writeIXML(SafetyNetSetup.iXML.replacingOccurrences(of: "<NOTE>Setup</NOTE>", with: "<NOTE>\(String(repeating: "a", count: 40))</NOTE>"), to: url, fileType: .wav)
        let first = try Layout(url: url)

        try ProductionChunks.writeIXML(SafetyNetSetup.iXML.replacingOccurrences(of: "<NOTE>Setup</NOTE>", with: "<NOTE>\(String(repeating: "b", count: 80))</NOTE>"), to: url, fileType: .wav)
        let second = try Layout(url: url)

        #expect(second.offset(of: "iXML") == first.offset(of: "iXML"))
        #expect(second.fileLength == first.fileLength)
        #expect(ProductionChunks.readIXML(from: url, fileType: .wav)?.contains(String(repeating: "b", count: 80)) == true)
    }

    /// Two chunks appended by one save each keep room to grow, rather than the second taking the first's.
    @Test func eachAppendedChunkKeepsItsReserve() async throws {
        let url = try recorderFixture(form: .riff)
        var description = try await MetaAudioFileDescription(parsing: url)
        description.iXMLMetadata = try #require(description.iXMLMetadata).replacingOccurrences(of: "<NOTE>Setup</NOTE>", with: "<NOTE>\(String(repeating: "d", count: 3000))</NOTE>")
        description.tagProperties[.title] = String(repeating: "t", count: 6000)
        try description.save(dirtyFlags: [.tags])
        let first = try Layout(url: url)

        try ProductionChunks.writeIXML(SafetyNetSetup.iXML.replacingOccurrences(of: "<NOTE>Setup</NOTE>", with: "<NOTE>\(String(repeating: "e", count: 3040))</NOTE>"), to: url, fileType: .wav)
        let second = try Layout(url: url)

        #expect(second.offset(of: "iXML") == first.offset(of: "iXML"))
        #expect(second.fileLength == first.fileLength)
    }

    /// A chunk that moves or is removed leaves nothing of itself readable behind.
    @Test(arguments: Form.allCases)
    func vacatedChunkIsCleared(form: Form) async throws {
        let url = try recorderFixture(form: form)
        let grown = SafetyNetSetup.iXML.replacingOccurrences(of: "<NOTE>Setup</NOTE>", with: "<NOTE>\(String(repeating: "c", count: 2000))</NOTE>")

        try ProductionChunks.writeIXML(grown, to: url, fileType: .wav)
        #expect(try Data(contentsOf: url).range(of: Data(SafetyNetSetup.iXMLProject.utf8)) != nil)

        try ProductionChunks.removeAll(from: url, fileType: .wav)
        #expect(try Data(contentsOf: url).range(of: Data(SafetyNetSetup.iXMLProject.utf8)) == nil)
        #expect(ProductionChunks.readIXML(from: url, fileType: .wav) == nil)
    }

    /// A new chunk goes after the last one TagLib can walk to, never behind bytes it cannot read.
    @Test func newChunkIsReachablePastTrailingBytes() async throws {
        let url = try recorderFixture(form: .riff)
        try StoredXMPPacketWrite.remove.write(to: url)

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A]))
        try handle.close()

        try StoredXMPPacketWrite.replace(SafetyNetSetup.xmpPacket(title: "Reachable")).write(to: url)

        #expect(TagLibBridge.storedXMPPacket(url.path)?.contains("Reachable") == true)
    }

    /// An artwork the encoder rejects fails the save after everything else is written.
    @Test func artworkEncodeFailureThrows() async throws {
        let url = try recorderFixture(form: .riff)
        var description = try await MetaAudioFileDescription(parsing: url)

        // Wider than JPEG can store, and JPEG is where an untyped image is encoded.
        let context = try #require(CGContext(
            data: nil, width: 70000, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        description.imageDescription.cgImage = context.makeImage()
        description.tagProperties[.title] = Self.editedTitle

        #expect(throws: MetadataError.incompleteSave(written: Set(MetadataDirtyFlag.tags.components), failures: [.writeFailed(.artwork, url)])) {
            try description.save(dirtyFlags: [.tags, .image])
        }

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == Self.editedTitle)
    }

    // MARK: - Writers

    private func write(_ writer: Writer, to url: URL) async throws {
        switch writer {
        case .titleSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.editedTitle
            try description.save(dirtyFlags: [.tags])

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
            bext.sequenceDescription = SafetyNetEdit.bextSequenceDescription
            description.bextDescription = bext
            try description.save(dirtyFlags: [.tags])

        case .packetReplace:
            var description = try await MetaAudioFileDescription(parsing: url)
            try description.save(dirtyFlags: [], storedXMPPacket: .replace(SafetyNetEdit.packet))

        case .packetRemove:
            var description = try await MetaAudioFileDescription(parsing: url)
            try description.save(dirtyFlags: [], storedXMPPacket: .remove)

        case .tagPropertiesSave:
            var tags = try TagProperties(url: url)
            tags[.title] = Self.editedTitle
            try tags.save(to: url)

        case .artworkWrite:
            let artwork = try #require(EmbeddedArtwork(contentsOf: TestBundleResources.shared.songbird))
            try artwork.write(to: url)

        case .artworkRemove:
            try EmbeddedArtwork.remove(from: url)

        case .markersWrite:
            try EmbeddedMarkers.write(SafetyNetEdit.markers, to: url, fileType: .wav)

        case .markersRemove:
            try EmbeddedMarkers.removeAll(from: url, fileType: .wav)

        case .productionBEXTWrite:
            var bext = try #require(ProductionChunks.readBEXT(from: url, fileType: .wav))
            bext.sequenceDescription = SafetyNetEdit.bextSequenceDescription
            try ProductionChunks.writeBEXT(bext, to: url, fileType: .wav)

        case .productionIXMLWrite:
            try ProductionChunks.writeIXML(SafetyNetSetup.iXML.replacingOccurrences(of: SafetyNetSetup.iXMLProject, with: Self.editedProject), to: url, fileType: .wav)

        case .productionChunksRemove:
            try ProductionChunks.removeAll(from: url, fileType: .wav)

        case .bextDescriptionWrite:
            var bext = try #require(ProductionChunks.readBEXT(from: url, fileType: .wav))
            bext.sequenceDescription = SafetyNetEdit.bextSequenceDescription
            try BEXTDescription.write(bextDescription: bext, to: url)

        case .ratingWrite:
            #expect(TagRating.write(2, toPath: url.path))
        }
    }

    private func expectWritten(_ writer: Writer, in url: URL) async throws {
        switch writer {
        case .titleSave, .tagPropertiesSave:
            #expect(try TagProperties(url: url)[.title] == Self.editedTitle)

        case .markerSave, .markersWrite:
            let markers = try await AudioMarkerDescriptionCollection(url: url, fileType: .wav)
            #expect(markers.markerDescriptions.map(\.name) == SafetyNetEdit.markers.map(\.name))

        case .markersRemove:
            let markers = try await AudioMarkerDescriptionCollection(url: url, fileType: .wav)
            #expect(markers.markerDescriptions.isEmpty)

        case .artworkSave, .artworkWrite:
            #expect(try EmbeddedArtwork.read(from: url) != nil)

        case .artworkRemove:
            #expect(try EmbeddedArtwork.read(from: url) == nil)

        case .bextSave, .productionBEXTWrite, .bextDescriptionWrite:
            #expect(ProductionChunks.readBEXT(from: url, fileType: .wav)?.sequenceDescription == SafetyNetEdit.bextSequenceDescription)

        case .packetReplace:
            #expect(TagLibBridge.storedXMPPacket(url.path) == SafetyNetEdit.packet)

        case .packetRemove:
            #expect(TagLibBridge.storedXMPPacket(url.path) == nil)

        case .productionIXMLWrite:
            #expect(ProductionChunks.readIXML(from: url, fileType: .wav)?.contains(Self.editedProject) == true)

        case .productionChunksRemove:
            #expect(ProductionChunks.readBEXT(from: url, fileType: .wav) == nil)
            #expect(ProductionChunks.readIXML(from: url, fileType: .wav) == nil)

        case .ratingWrite:
            #expect(TagRating.read(url.path) == 2)
        }
    }

    // MARK: - Fixture

    /// `tabla.wav` with a `bext`, iXML and XMP packet added and `data` moved behind every other chunk.
    private func recorderFixture(form: Form) throws -> URL {
        let url = bin.appendingPathComponent("recorder-\(form.rawValue).wav")
        try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_wav, to: url)

        try RIFFChunkBuilder.rewrite(url) { chunks in
            chunks.insert(contentsOf: [
                RIFFChunks.Chunk(id: "bext", payload: SafetyNetRIFFForeign.broadcastExtension),
                RIFFChunks.Chunk(id: "iXML", payload: Data(SafetyNetSetup.iXML.utf8)),
                RIFFChunks.Chunk(id: "_PMX", payload: Data(SafetyNetSetup.packet.utf8)),
            ], at: 1)

            guard let index = chunks.firstIndex(where: { $0.id == "data" }) else { throw RIFFChunkBuilder.MissingChunk() }
            chunks.append(chunks.remove(at: index))
        }

        if form == .rf64 {
            try RIFFChunkBuilder.convertToLongForm(url)
        }

        return url
    }
}

/// Where each chunk sits, by the same walk any RIFF reader makes.
private struct Layout {
    let chunks: [RIFFChunks.Chunk]
    let offsets: [Int]
    let fileLength: Int
    /// The form size the file states: the `RIFF` size field, or `ds64`'s for a long-form file.
    let storedSize: UInt64

    init(url: URL) throws {
        let file = try Data(contentsOf: url)
        let riff = try RIFFChunks(file)

        chunks = riff.chunks
        var offset = 12
        var offsets: [Int] = []
        for chunk in riff.chunks {
            offsets.append(offset)
            offset += 8 + chunk.payload.count + chunk.payload.count % 2
        }
        self.offsets = offsets
        fileLength = file.count

        if let sizes = riff.longFormSizes {
            storedSize = sizes.riffSize
        } else {
            storedSize = file.dropFirst(4).prefix(4).reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        }
    }

    /// The form size the chunks add up to.
    var walkedSize: UInt64 {
        guard let last = chunks.last, let offset = offsets.last else { return 4 }
        return UInt64(offset + last.payload.count + last.payload.count % 2)
    }

    var dataOffset: Int? { offset(of: "data") }

    var data: Data? { chunks.first { $0.id == "data" }?.payload }

    func offset(of id: String) -> Int? {
        chunks.firstIndex { $0.id == id }.map { offsets[$0] }
    }
}
