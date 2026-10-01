// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

/// A tag save leaves the file's stored XMP packet byte-identical: WAV `_PMX`, AIFF `APPL`/`XMP `,
/// and the MP3 ID3v2 `PRIV` frame owned by `XMP`.
@Suite(.tags(.file))
final class XMPStorageSurvivalTests: BinTestCase {
    private let packet = Data(
        #"<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?><x:xmpmeta xmlns:x="adobe:ns:meta/"/><?xpacket end="w"?>  "#.utf8
    )

    @Test func aWaveTagSaveKeepsThePMXChunk() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        try IFFChunks.append(id: "_PMX", payload: packet, to: url, bigEndian: false)
        #expect(try IFFChunks.payload(id: "_PMX", in: url, bigEndian: false) == packet)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Saved Title")
        try description.save(dirtyFlags: [.metadata])

        #expect(try IFFChunks.payload(id: "_PMX", in: url, bigEndian: false) == packet)
    }

    @Test func anAIFFTagSaveKeepsTheXMPApplicationChunk() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        let payload = Data("XMP ".utf8) + packet
        try IFFChunks.append(id: "APPL", payload: payload, to: url, bigEndian: true)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Saved Title")
        try description.save(dirtyFlags: [.metadata])

        #expect(try IFFChunks.payload(id: "APPL", in: url, bigEndian: true) == payload)
    }

    @Test func anMP3TagSaveKeepsTheXMPPrivateFrame() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_xmp)
        let original = try #require(try ID3v2Frames.xmpPacket(in: url))

        var description = try await MetaAudioFileDescription(parsing: url)
        description.set(tag: .title, value: "Saved Title")
        try description.save(dirtyFlags: [.metadata])

        let saved = try ID3v2Frames.xmpPacket(in: url)
        #expect(saved == original)
    }
}

/// A native save that replaces or removes the stored packet writes it as given, in the same save.
@Suite(.tags(.file))
final class StoredXMPPacketWriteTests: BinTestCase {
    private let packet = #"<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?><x:xmpmeta xmlns:x="adobe:ns:meta/"/><?xpacket end="w"?>"#

    @Test func aWaveSaveStoresTheReplacementPacket() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        let bext = try IFFChunks.payload(id: "bext", in: url, bigEndian: false)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], storedXMPPacket: .replace(packet))

        #expect(try IFFChunks.payload(id: "_PMX", in: url, bigEndian: false) == Data(packet.utf8))
        #expect(StoredXMPPacketWrite.storedPacket(in: url) == packet)
        #expect(try IFFChunks.payload(id: "bext", in: url, bigEndian: false) == bext)
    }

    @Test func aWaveSaveRemovesThePacket() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        try IFFChunks.append(id: "_PMX", payload: Data(packet.utf8), to: url, bigEndian: false)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], storedXMPPacket: .remove)

        #expect(try IFFChunks.payload(id: "_PMX", in: url, bigEndian: false) == nil)
        #expect(StoredXMPPacketWrite.storedPacket(in: url) == nil)
    }

    @Test func anMP3SaveStoresTheReplacementPacket() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_xmp)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [.metadata], storedXMPPacket: .replace(packet))

        #expect(try ID3v2Frames.xmpPacket(in: url) == Data(packet.utf8))
        #expect(StoredXMPPacketWrite.storedPacket(in: url) == packet)
    }

    @Test func anMP3SaveRemovesThePacket() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_xmp)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], storedXMPPacket: .remove)

        #expect(try ID3v2Frames.xmpPacket(in: url) == nil)
    }

    @Test func aFormatWithoutAStoredPacketIsRefusedUntouched() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        let before = try Data(contentsOf: url)

        var description = try await MetaAudioFileDescription(parsing: url)
        #expect(throws: (any Error).self) {
            try description.save(dirtyFlags: [.metadata], storedXMPPacket: .replace(self.packet))
        }

        #expect(try Data(contentsOf: url) == before)
    }
}
