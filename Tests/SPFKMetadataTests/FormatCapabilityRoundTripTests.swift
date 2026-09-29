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
/// must round-trip, and an unlisted one must refuse with ``UnstorableMetadataError``.
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

            #expect(throws: UnstorableMetadataError(fileType: fileType, flags: [.metadata])) {
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

            #expect(throws: UnstorableMetadataError(fileType: fileType, flags: [.markers])) {
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

    #if os(macOS)
    /// Tags and artwork an untaggable file refuses still leave the Finder tags written.
    @Test func finderTagsAreWrittenBeforeTheRefusal() async throws {
        let url = try copy(TestBundleResources.shared.tabla_caf)
        var description = MetaAudioFileDescription(url: url, fileType: .caf)
        description.tagProperties[.title] = "Unstorable"
        description.urlProperties.finderTags = FinderTagGroup(tags: [FinderTagDescription(label: "Unstorable")])

        #expect(throws: UnstorableMetadataError(fileType: .caf, flags: [.metadata])) {
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

        #expect(throws: UnstorableMetadataError(fileType: .caf, flags: [.metadata])) {
            try description.save(dirtyFlags: [.metadata])
        }

        #expect(URLProperties(url: URL(fileURLWithPath: url.path)).modificationDate == before)
    }
    #endif
}
