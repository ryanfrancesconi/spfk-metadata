// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// Markers set on a `.mov` used to be discarded in silence: `saveMarkers()` sent the type to a
/// `default` that logged and returned, so the save reported success and cleared the dirty flag
/// while writing nothing, and the matching reader threw "unsupported file type". Both were an
/// oversight from when this workflow only ever saw audio containers — a QuickTime chapter track
/// is `.mov`'s native marker format and TagLib writes it happily.
///
/// These go through `MetaAudioFileDescription.save` and `AudioMarkerDescriptionCollection(url:)`
/// rather than the underlying utility, because the utility was never the broken part — the
/// format dispatch around it was.
@Suite
final class VideoContainerMarkerTests {
    @Test(arguments: [AudioFileType.mov, .m4v, .mp4])
    func roundTripsMarkersThroughAVideoContainer(fileType: AudioFileType) async throws {
        let url = try await Self.makeContainer(fileType)
        defer { try? FileManager.default.removeItem(at: url) }

        var description = MetaAudioFileDescription(url: url, fileType: fileType)
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "Start", startTime: 0.5),
            AudioMarkerDescription(name: "Middle", startTime: 1.5),
            AudioMarkerDescription(name: "End", startTime: 2.5),
        ])

        try description.save(dirtyFlags: [.markers])

        let readBack = try await AudioMarkerDescriptionCollection(url: url, fileType: fileType)

        #expect(readBack.markerDescriptions.count == 3)
        #expect(readBack.markerDescriptions.map(\.name) == ["Start", "Middle", "End"])
        for (marker, expected) in zip(readBack.markerDescriptions, [0.5, 1.5, 2.5]) {
            #expect(abs(marker.startTime - expected) < 0.01)
        }
    }

    /// A region marker carries its duration and color through the chapter title encoding —
    /// worth asserting separately, since that payload is what distinguishes a segment marker
    /// from a plain cue on read-back.
    @Test func preservesRegionMarkersThroughAQuickTimeContainer() async throws {
        let url = try await Self.makeContainer(.mov)
        defer { try? FileManager.default.removeItem(at: url) }

        var description = MetaAudioFileDescription(url: url, fileType: .mov)
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "Segment", startTime: 1.0, endTime: 2.0, markerType: .region),
        ])

        try description.save(dirtyFlags: [.markers])

        let readBack = try await AudioMarkerDescriptionCollection(url: url, fileType: .mov)
        let marker = try #require(readBack.markerDescriptions.first)

        #expect(marker.name == "Segment")
        #expect(marker.markerType == .region)
        #expect(abs((marker.endTime ?? 0) - 2.0) < 0.05)
    }

    /// A format that genuinely can't hold markers must say so rather than report a clean save —
    /// the silent return is what let the original bug go unnoticed.
    @Test func throwsRatherThanDiscardingMarkersForAnUnsupportedFormat() async throws {
        let source = TestBundleResources.shared.tabla_wav
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }

        try await Self.export(source, to: url, fileType: .caf)

        var description = MetaAudioFileDescription(url: url, fileType: .caf)
        description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: [
            AudioMarkerDescription(name: "Nope", startTime: 1.0),
        ])

        #expect(throws: (any Error).self) {
            try description.save(dirtyFlags: [.markers])
        }
    }

    // MARK: - Fixtures

    /// Remuxes the bundled `tabla.mp4` into the requested container so the test exercises a real
    /// QuickTime/ISO file without adding another binary to the test bundle.
    private static func makeContainer(_ fileType: AudioFileType) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileType.rawValue)

        try await export(TestBundleResources.shared.tabla_mp4, to: url, fileType: fileType)
        return url
    }

    private static func export(_ source: URL, to output: URL, fileType: AudioFileType) async throws {
        let outputFileType: AVFileType = switch fileType {
        case .mov: .mov
        case .m4v: .m4v
        case .caf: .caf
        default: .mp4
        }

        let session = try #require(
            AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetPassthrough)
        )
        session.outputURL = output
        session.outputFileType = outputFileType

        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { c.resume() }
        }

        guard session.status == .completed else {
            throw NSError(
                domain: "VideoContainerMarkerTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: session.error?.localizedDescription ?? "export failed"]
            )
        }
    }
}
