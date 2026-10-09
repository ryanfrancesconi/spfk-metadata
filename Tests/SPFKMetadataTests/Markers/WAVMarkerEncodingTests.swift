// Copyright Ryan Francesconi. All Rights Reserved.

import AudioToolbox
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// WAV marker names are stored in `labl` sub-chunks: written as UTF-8, read as UTF-8 when the
/// bytes are valid UTF-8 and as Windows-1252 otherwise.
@Suite(.tags(.file))
final class WAVMarkerEncodingTests: BinTestCase {
    private let color = HexColor(string: "0000FFFF")

    // MARK: - Round trip

    @Test(arguments: ["日本", "Привет", "Kick 🥁", "café — Don’t"])
    func markerNameRoundTrips(name: String) async throws {
        for fixture in [TestBundleResources.shared.tabla_wav, TestBundleResources.shared.tabla_aif] {
            let url = try copyToBin(url: fixture)

            var description = try await MetaAudioFileDescription(parsing: url)
            description.markerCollection.update(markerDescriptions: [
                AudioMarkerDescription(name: name, startTime: 0.5, endTime: 13, hexColor: color, markerType: .region),
            ])
            try description.save(dirtyFlags: [.markers])

            let reparsed = try await MetaAudioFileDescription(parsing: url)
            let marker = try #require(reparsed.markerCollection.markerDescriptions.first)

            #expect(reparsed.markerCollection.markerDescriptions.count == 1)
            #expect(marker.name == name, "\(fixture.lastPathComponent)")
            #expect(marker.hexColor == color)
            #expect(marker.markerType == .region)
            #expect(marker.endTime == 13)
        }
    }

    // MARK: - Encoding on disk

    /// iZotope RX crashes opening a WAV whose `labl` is not valid UTF-8.
    @Test(arguments: ["café", "Intro — take 2", "Don’t"])
    func writtenLabelsAreUTF8(name: String) throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let marker = AudioMarker(name: name, time: 0.5, sampleRate: 48000, markerID: 0)
        #expect(AudioMarkerUtil.write([marker], to: url))

        let labels = try labelBytes(in: url)
        #expect(labels.count == 1)

        for bytes in labels {
            #expect(String(bytes: bytes, encoding: .utf8) == name)
        }
    }

    /// Other readers find the chunks: Core Audio sees the same cue points at the same frames.
    @Test func coreAudioReadsWrittenMarkers() throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let markers = [
            AudioMarker(name: "One", time: 0.5, sampleRate: 48000, markerID: 0),
            AudioMarker(name: "Two", time: 1, sampleRate: 48000, markerID: 1),
        ]
        #expect(AudioMarkerUtil.write(markers, to: url))

        let read = try coreAudioReadMarkers(from: url)
        #expect(read.map(\.name) == ["One", "Two"])
        #expect(read.map(\.frame) == [24000, 48000])
    }

    /// `adtl` and `INFO` are both `LIST` chunks, told apart only by their type ID.
    @Test func rewritingKeepsOneOfEachChunk() throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let before = try topLevelChunkIDs(in: url)
        #expect(before.filter { $0 == "cue " }.count == 1)
        #expect(try listTypes(in: url).sorted() == ["INFO", "adtl"])

        for name in ["One", "Two"] {
            let marker = AudioMarker(name: name, time: 0.5, sampleRate: 48000, markerID: 0)
            #expect(AudioMarkerUtil.write([marker], to: url))
        }

        #expect(try topLevelChunkIDs(in: url).filter { $0 == "cue " }.count == 1)
        #expect(try listTypes(in: url).sorted() == ["INFO", "adtl"])
        #expect((AudioMarkerUtil.read(url) as? [AudioMarker])?.map(\.name) == ["Two"])
    }

    @Test func removeLeavesNoMarkerChunks() throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        #expect(try labelBytes(in: url).count == 5)

        #expect(AudioMarkerUtil.remove(url))

        #expect(try labelBytes(in: url).isEmpty)
        #expect(try topLevelChunkIDs(in: url).contains("cue ") == false)
        #expect(try listTypes(in: url) == ["INFO"])
        #expect((AudioMarkerUtil.read(url) as? [AudioMarker] ?? []).isEmpty)
    }

    // MARK: - Reading other writers' files

    /// Files ShadowTag saved before names were written as UTF-8.
    @Test func coreAudioWrittenNamesRead() throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        let names = ["café", "Intro — take 2", "Don’t"]
        try coreAudioWriteMarkers(names: names, to: url)

        let markers = try #require(AudioMarkerUtil.read(url) as? [AudioMarker])
        #expect(markers.map(\.name) == names)
    }

    /// The layout iZotope RX writes.
    @Test func utf8LabelWrittenByAnotherToolReads() throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        try coreAudioWriteMarkers(names: ["cafXX"], to: url)

        var data = try Data(contentsOf: url)
        let range = try #require(data.range(of: Data("cafXX".utf8)))
        data.replaceSubrange(range, with: Data("café".utf8))
        try data.write(to: url)

        let markers = try #require(AudioMarkerUtil.read(url) as? [AudioMarker])
        #expect(markers.map(\.name) == ["café"])
    }

    // MARK: - Other chunks

    @Test func otherChunksSurviveAMarkerSave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        let iXML = "<BWFXML><PROJECT>probe</PROJECT></BWFXML>"

        let waveFile = WaveFileC(path: url.path)
        #expect(waveFile.load())
        waveFile.iXML = iXML
        waveFile.markersNeedsSave = false
        #expect(waveFile.save())

        let before = try await MetaAudioFileDescription(parsing: url)
        #expect(before.bextDescription != nil)

        var description = before
        description.markerCollection.update(markerDescriptions: [
            AudioMarkerDescription(name: "日本", startTime: 0.5, hexColor: color),
        ])
        try description.save(dirtyFlags: [.markers])

        let after = try await MetaAudioFileDescription(parsing: url)
        #expect(after.bextDescription == before.bextDescription)
        #expect(after.iXMLMetadata?.contains("probe") == true)
        #expect(after.tagProperties.tags == before.tagProperties.tags)
        #expect(after.markerCollection.markerDescriptions.map(\.name) == ["日本"])
    }

    @Test func markersSurviveATagOnlySave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.markerCollection.update(markerDescriptions: [
            AudioMarkerDescription(name: "Привет", startTime: 0.5, hexColor: color),
        ])
        try description.save(dirtyFlags: [.markers])

        var tagged = try await MetaAudioFileDescription(parsing: url)
        tagged.tagProperties[.title] = "NEW TITLE"
        try tagged.save(dirtyFlags: [.tags])

        let after = try await MetaAudioFileDescription(parsing: url)
        #expect(after.tagProperties[.title] == "NEW TITLE")
        #expect(after.markerCollection.markerDescriptions.map(\.name) == ["Привет"])
        #expect(after.markerCollection.markerDescriptions.first?.hexColor == color)
        #expect(try listTypes(in: url).sorted() == ["INFO", "adtl"])
    }

    // MARK: - Helpers

    /// Writes markers the way `AudioMarkerUtil` did through Core Audio, which stores names as Windows-1252.
    private func coreAudioWriteMarkers(names: [String], to url: URL) throws {
        var fileID: AudioFileID?
        try #require(AudioFileOpenURL(url as CFURL, .readWritePermission, 0, &fileID) == noErr)
        let file = try #require(fileID)
        defer { AudioFileClose(file) }

        let size = NumAudioFileMarkersToNumBytes(names.count)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        defer { raw.deallocate() }

        let list = raw.bindMemory(to: AudioFileMarkerList.self, capacity: 1)
        list.pointee.mNumberMarkers = UInt32(names.count)

        let cfNames = names.map { $0 as CFString }

        withUnsafeMutablePointer(to: &list.pointee.mMarkers) { pointer in
            pointer.withMemoryRebound(to: AudioFileMarker.self, capacity: names.count) { markers in
                for i in names.indices {
                    markers[i] = AudioFileMarker()
                    markers[i].mName = Unmanaged.passUnretained(cfNames[i])
                    markers[i].mFramePosition = Float64(i * 1000)
                    markers[i].mMarkerID = Int32(i)
                }
            }
        }

        let status = AudioFileSetProperty(file, kAudioFilePropertyMarkerList, UInt32(size), list)
        withExtendedLifetime(cfNames) {}
        try #require(status == noErr)
    }

    private func coreAudioReadMarkers(from url: URL) throws -> [(name: String?, frame: Float64)] {
        var fileID: AudioFileID?
        try #require(AudioFileOpenURL(url as CFURL, .readPermission, 0, &fileID) == noErr)
        let file = try #require(fileID)
        defer { AudioFileClose(file) }

        var size: UInt32 = 0
        try #require(AudioFileGetPropertyInfo(file, kAudioFilePropertyMarkerList, &size, nil) == noErr)

        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        defer { raw.deallocate() }
        try #require(AudioFileGetProperty(file, kAudioFilePropertyMarkerList, &size, raw) == noErr)

        let list = raw.bindMemory(to: AudioFileMarkerList.self, capacity: 1)
        let count = Int(list.pointee.mNumberMarkers)

        return withUnsafeMutablePointer(to: &list.pointee.mMarkers) { pointer in
            pointer.withMemoryRebound(to: AudioFileMarker.self, capacity: count) { markers in
                (0 ..< count).map { i in
                    (markers[i].mName.map { $0.takeRetainedValue() as String }, markers[i].mFramePosition)
                }
            }
        }
    }

    private func listTypes(in url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        return chunks(in: data, from: 12).filter { $0.id == "LIST" }.map {
            String(decoding: data[$0.body.lowerBound ..< $0.body.lowerBound + 4], as: UTF8.self)
        }
    }

    private func topLevelChunkIDs(in url: URL) throws -> [String] {
        try chunks(in: Data(contentsOf: url), from: 12).map(\.id)
    }

    /// The text of every `labl`, without its cue ID or null terminator.
    private func labelBytes(in url: URL) throws -> [[UInt8]] {
        let data = try Data(contentsOf: url)
        let adtl = Data("adtl".utf8)
        var labels: [[UInt8]] = []

        for list in chunks(in: data, from: 12) where list.id == "LIST" {
            let body = list.body
            guard data[body.lowerBound ..< body.lowerBound + 4] == adtl else { continue }

            for sub in chunks(in: data, from: body.lowerBound + 4, to: body.upperBound) where sub.id == "labl" {
                let text = data[(sub.body.lowerBound + 4) ..< sub.body.upperBound]
                labels.append(Array(text.prefix { $0 != 0 }))
            }
        }

        return labels
    }

    private func chunks(in data: Data, from start: Int, to end: Int? = nil) -> [(id: String, body: Range<Int>)] {
        let end = end ?? data.count
        var result: [(id: String, body: Range<Int>)] = []
        var offset = data.startIndex + start

        while offset + 8 <= end {
            let id = String(decoding: data[offset ..< offset + 4], as: UTF8.self)
            var size = 0
            for (i, byte) in data[offset + 4 ..< offset + 8].enumerated() {
                size |= Int(byte) << (8 * i)
            }
            let bodyStart = offset + 8
            result.append((id, bodyStart ..< min(bodyStart + size, end)))
            offset = bodyStart + size + (size & 1)
        }

        return result
    }
}
