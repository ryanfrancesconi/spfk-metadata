// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKFileSystem
import SPFKMetadataBase
import SPFKTesting
import SPFKUtils
import Testing

@testable import SPFKMetadata

/// Pins `AudioFileType.metadataTypes` and `markerWriteTypes` against the writers: a listed type
/// must round-trip, and an unlisted one must refuse with ``MetadataError/unstorable(_:_:)``.
@Suite(.tags(.file))
final class FormatCapabilityRoundTripTests: BinTestCase {
    static let fixtures: [URL] = {
        let resources = TestBundleResources.shared

        return resources.oneFilePerContainer + [
            resources.sample_timecode_mov, resources.sample_timecode_offset_mov, resources.sample_dualaudio_mov,
        ]
    }()

    private func copy(_ source: URL) throws -> URL {
        let url = bin.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    @Test(arguments: fixtures)
    func tagsRoundTripExactlyWhereListed(source: URL) async throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))
        let title = "Round Trip \(fileType.rawValue)"

        guard fileType.supportsMetadata else {
            var description = MetaAudioFileDescription(url: url, fileType: fileType)
            description.tagProperties[.title] = title

            #expect(throws: MetadataError.incompleteSave(written: [], failures: [.unstorable(fileType, [.metadata])])) {
                try description.save(dirtyFlags: [.metadata])
            }
            return
        }

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = title
        try description.save(dirtyFlags: [.metadata])

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == title)
    }

    /// `RATING` bypasses the PropertyMap, so each listed container needs its own rating branch.
    @Test(arguments: fixtures)
    func ratingRoundTripsWhereListed(source: URL) async throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))
        guard fileType.supportsMetadata else { return }

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.rating] = "4"
        try description.save(dirtyFlags: [.metadata])

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.rating] == "4", "\(fileType.rawValue)")
    }

    @Test(arguments: fixtures)
    func markersRoundTripExactlyWhereListed(source: URL) async throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))
        let marker = AudioMarkerDescription(name: "Marker", startTime: 0.1)

        guard fileType.supportsMarkerWrite else {
            var description = MetaAudioFileDescription(url: url, fileType: fileType)
            description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [marker])

            #expect(throws: MetadataError.incompleteSave(written: [], failures: [.unstorable(fileType, [.markers])])) {
                try description.save(dirtyFlags: [.markers])
            }
            return
        }

        var description = try await MetaAudioFileDescription(parsing: url)
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [marker])
        try description.save(dirtyFlags: [.markers])

        let reread = try await MetaAudioFileDescription(parsing: url)
        let markers = reread.markerCollection.markerDescriptions
        #expect(markers.count == 1)
        #expect(abs((markers.first?.startTime ?? -1) - marker.startTime) < 0.01)
    }

    static let markerWriteFixtures: [URL] = TestBundleResources.shared.oneFilePerContainer.filter {
        AudioFileType(url: $0)?.supportsMarkerWrite == true
    }

    /// A tags-only save from the same description keeps the markers a marker save just wrote.
    @Test(arguments: markerWriteFixtures)
    func markersSurviveATagsOnlySave(source: URL) async throws {
        let url = try copy(source)
        let fileType = try #require(AudioFileType(url: url))
        let written = [
            AudioMarkerDescription(name: "First", startTime: 0.1),
            AudioMarkerDescription(name: "Second", startTime: 0.3),
        ]

        var description = try await MetaAudioFileDescription(parsing: url)
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: written)
        try description.save(dirtyFlags: [.markers])

        description.tagProperties[.title] = "Tags Only"
        try description.save(dirtyFlags: [.metadata])

        let reread = try await MetaAudioFileDescription(parsing: url)
        let markers = reread.markerCollection.markerDescriptions

        #expect(reread.tagProperties[.title] == "Tags Only", "\(fileType.rawValue)")
        #expect(markers.map(\.name) == written.map(\.name), "\(fileType.rawValue)")
        #expect(markers.map { ($0.startTime * 10).rounded() } == [1, 3], "\(fileType.rawValue)")
    }

    #if os(macOS)
    /// Tags and artwork an untaggable file refuses still leave the Finder tags written.
    @Test func finderTagsAreWrittenBeforeTheRefusal() async throws {
        let url = try copy(TestBundleResources.shared.tabla_caf)
        var description = MetaAudioFileDescription(url: url, fileType: .caf)
        description.tagProperties[.title] = "Unstorable"
        description.urlProperties.finderTags = FinderTagGroup(tags: [FinderTagDescription(label: "Unstorable")])

        #expect(throws: MetadataError.incompleteSave(written: [.finderTags], failures: [.unstorable(.caf, [.metadata])])) {
            try description.save(dirtyFlags: [.metadata, .finderTags])
        }

        // A fresh URL: the original's resource values were cached when the description was built.
        #expect(FinderTagGroup(url: URL(fileURLWithPath: url.path)).tags.map(\.label) == ["Unstorable"])
    }

    /// A save with nothing it can write leaves the file alone rather than bumping its date.
    @Test func aRefusedSaveLeavesTheFileUntouched() async throws {
        let url = try copy(TestBundleResources.shared.tabla_caf)
        let before = try #require(URLProperties(url: url).modificationDate)

        var description = MetaAudioFileDescription(url: url, fileType: .caf)
        description.tagProperties[.title] = "Unstorable"

        #expect(throws: MetadataError.incompleteSave(written: [], failures: [.unstorable(.caf, [.metadata])])) {
            try description.save(dirtyFlags: [.metadata])
        }

        #expect(URLProperties(url: URL(fileURLWithPath: url.path)).modificationDate == before)
    }
    #endif
}
