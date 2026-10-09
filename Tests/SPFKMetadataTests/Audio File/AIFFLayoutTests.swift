// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AudioToolbox
import AVFoundation
import CoreGraphics
import Foundation
import SPFKBase
import SPFKImage
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A tag, artwork or marker save leaves an AIFF's `SSND` where it was: tags and artwork on a file
/// whose `ID3 ` chunk precedes it, markers on one with nothing ahead of it to grow into.
@Suite(.tags(.file))
final class AIFFLayoutTests: BinTestCase {
    enum Writer: String, CaseIterable, CustomTestStringConvertible {
        case titleSave
        case artworkSave
        case titleAndArtworkSave
        case tagPropertiesSave
        case markerSave
        case everythingSave

        var testDescription: String { rawValue }
    }

    /// Longer than the padding TagLib renders into an ID3v2 tag, so the chunk grows.
    private static let longTitle = String(repeating: "AIFF layout ", count: 400)

    @Test(arguments: Writer.allCases)
    func aSaveLeavesTheSoundDataInPlace(writer: Writer) async throws {
        let writesMarkers = writer == .markerSave || writer == .everythingSave
        let url = try writesMarkers ? bareFixture() : leadingID3Fixture()
        let before = try Self.soundChunk(in: url)

        switch writer {
        case .titleSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.longTitle
            try description.save(dirtyFlags: [.tags])
        case .artworkSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.imageDescription.cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
            try description.save(dirtyFlags: [.image])
        case .titleAndArtworkSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.longTitle
            description.imageDescription.cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
            try description.save(dirtyFlags: [.tags, .image])
        case .tagPropertiesSave:
            var properties = try TagProperties(url: url)
            properties[.title] = Self.longTitle
            try properties.save(to: url)
        case .markerSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.markerCollection = Self.storableMarkers
            try description.save(dirtyFlags: [.markers])
        case .everythingSave:
            var description = try await MetaAudioFileDescription(parsing: url)
            description.tagProperties[.title] = Self.longTitle
            description.imageDescription.cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
            description.markerCollection = Self.storableMarkers
            try description.save(dirtyFlags: [.tags, .image, .markers])
        }

        let after = try Self.soundChunk(in: url)
        #expect(after.offset == before.offset)
        #expect(after.payload == before.payload)

        let reread = try await MetaAudioFileDescription(parsing: url)
        if [.titleSave, .titleAndArtworkSave, .tagPropertiesSave, .everythingSave].contains(writer) {
            #expect(reread.tagProperties[.title] == Self.longTitle)
        }
        if [.artworkSave, .titleAndArtworkSave, .everythingSave].contains(writer) {
            #expect(reread.imageDescription.cgImage != nil)
        }
        if writesMarkers {
            #expect(reread.markerCollection.markerDescriptions.map(\.name) == Self.storableMarkers.markerDescriptions.map(\.name))
        }

        let original = try AVAudioFile(forReading: TestBundleResources.shared.tabla_aif)
        #expect(try AVAudioFile(forReading: url).length == original.length)
    }

    /// A non-ASCII name, the longest name a `MARK` holds, and positions between frames.
    private static let storableMarkers = AudioMarkerDescriptionCollection(markerDescriptions: [
        AudioMarkerDescription(name: "First", startTime: 0.010_41),
        AudioMarkerDescription(name: "Ünïcødé ✓ 日本", startTime: 0.5),
        AudioMarkerDescription(name: String(repeating: "a", count: 255), startTime: 1.25),
    ])

    /// `storableMarkers`, an empty name, and a name one byte past what a `MARK` holds, which Core
    /// Audio stores as "?".
    private static let boundaryMarkers = AudioMarkerDescriptionCollection(
        markerDescriptions: storableMarkers.markerDescriptions + [
            AudioMarkerDescription(name: "", startTime: 2.000_01),
            AudioMarkerDescription(name: String(repeating: "b", count: 256), startTime: 1.5),
        ]
    )

    @Test func aMarkerSaveStoresWhatCoreAudioStores() async throws {
        let ours = try bareFixture()
        let coreAudio = bin.appendingPathComponent("core-audio.aif")
        try FileManager.default.copyItem(at: ours, to: coreAudio)

        var description = try await MetaAudioFileDescription(parsing: ours)
        description.markerCollection = Self.boundaryMarkers
        try description.save(dirtyFlags: [.markers])

        try Self.coreAudioWrite(description.audioMarkers, to: coreAudio)

        // Compared as parsed markers: Core Audio leaves a Pascal string's pad byte uninitialized.
        let expected = try AIFFChunks(contentsOf: coreAudio)
        let actual = try AIFFChunks(contentsOf: ours)
        #expect(try actual.markers() == expected.markers())
        #expect(actual.first("MARK")?.payload.count == expected.first("MARK")?.payload.count)
    }

    /// A name past 255 bytes reaching the writer untrimmed keeps its longest whole-character prefix.
    @Test func anOverlongRawMarkerNameIsTrimmedAtACharacter() async throws {
        let url = try bareFixture()
        let format = try #require(try await MetaAudioFileDescription(parsing: url).audioFormat)
        let name = "e\u{301}" + String(repeating: "日", count: 100) // 302 bytes; the first character is two scalars

        let marker = AudioMarker(name: name, time: 0.5, sampleRate: format.sampleRate, markerID: 0)
        #expect(AudioMarkerUtil.write([marker], to: url))

        let stored = try #require(try AIFFChunks(contentsOf: url).markers().first?.name)
        #expect(stored == "e\u{301}" + String(repeating: "日", count: 84))
    }

    /// A markers-only write keeps a tag stored after the sound data on a file with no room ahead of it.
    @Test func embeddedMarkersKeepATrailingTag() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        try AIFFChunkBuilder.rewrite(url) { chunks in chunks.removeAll { $0.id == "FLLR" || $0.id == "MARK" } }
        let tag = try #require(AIFFChunks(contentsOf: url).first("ID3 "))
        let before = try Self.soundChunk(in: url)

        let format = try #require(try await MetaAudioFileDescription(parsing: url).audioFormat)
        try EmbeddedMarkers.write(Self.storableMarkers.markerDescriptions, to: url, fileType: .aiff, fileSampleRate: format.sampleRate)

        let after = try AIFFChunks(contentsOf: url)
        #expect(after.first("ID3 ")?.payload == tag.payload)
        #expect(try after.markers().map(\.name) == Self.storableMarkers.markerDescriptions.map(\.name))
        #expect(try Self.soundChunk(in: url).offset == before.offset)
    }

    /// Core Audio's own marker write, the reference ours is compared with.
    private static func coreAudioWrite(_ markers: [AudioMarker], to url: URL) throws {
        var fileID: AudioFileID?
        try #require(AudioFileOpenURL(url as CFURL, .readWritePermission, 0, &fileID) == noErr)
        let file = try #require(fileID)
        defer { AudioFileClose(file) }

        var format = AudioStreamBasicDescription()
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try #require(AudioFileGetProperty(file, kAudioFilePropertyDataFormat, &formatSize, &format) == noErr)

        let size = NumAudioFileMarkersToNumBytes(markers.count)
        let list = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<AudioFileMarkerList>.alignment)
        defer { list.deallocate() }
        list.initializeMemory(as: UInt8.self, repeating: 0, count: size)
        list.assumingMemoryBound(to: AudioFileMarkerList.self).pointee.mNumberMarkers = UInt32(markers.count)

        let offset = try #require(MemoryLayout<AudioFileMarkerList>.offset(of: \AudioFileMarkerList.mMarkers))
        let entries = (list + offset).assumingMemoryBound(to: AudioFileMarker.self)
        let names = markers.map { NSString(string: $0.name ?? "") as CFString }

        for (index, marker) in markers.enumerated() {
            var entry = AudioFileMarker()
            entry.mFramePosition = marker.time * format.mSampleRate
            entry.mName = Unmanaged.passUnretained(names[index])
            entry.mMarkerID = Int32(index)
            entries[index] = entry
        }

        let status = withExtendedLifetime(names) { AudioFileSetProperty(file, kAudioFilePropertyMarkerList, UInt32(size), list) }
        try #require(status == noErr)
    }

    /// `tabla.aif` as `COMM`, `SSND`: no tag, filler or marker chunk.
    private func bareFixture() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        try AIFFChunkBuilder.rewrite(url) { chunks in chunks.removeAll { $0.id != "COMM" && $0.id != "SSND" } }
        return url
    }

    /// `tabla.aif` as `COMM`, `ID3 `, `SSND`: the tag ahead of the sound data, and no filler or
    /// marker chunk to grow into.
    private func leadingID3Fixture() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_aif)

        try AIFFChunkBuilder.rewrite(url) { chunks in
            let id3 = try #require(chunks.firstIndex { $0.id == "ID3 " })
            let tag = chunks.remove(at: id3)
            chunks.removeAll { $0.id == "FLLR" || $0.id == "MARK" }
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
