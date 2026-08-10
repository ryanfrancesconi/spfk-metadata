// Copyright Ryan Francesconi. All Rights Reserved.

import AVFoundation
import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// TEMPORARY diagnostic — points `MP4ChapterUtil.write` at a file named by
/// `SPFK_CHAPTER_PROBE_FILE` and prints the track set either side. Delete once the
/// video chapter-write defect is characterized.
@Suite(.tags(.development))
final class ChapterProbeDiagnostic {
    private func trackSummary(_ url: URL) async throws -> String {
        let tracks = try await AVURLAsset(url: url).load(.tracks)
        var parts: [String] = []
        for track in tracks {
            let formats = try await track.load(.formatDescriptions)
            let fourCC = formats.first.map { desc -> String in
                let c = CMFormatDescriptionGetMediaSubType(desc)
                let bytes = [UInt8((c >> 24) & 0xFF), UInt8((c >> 16) & 0xFF), UInt8((c >> 8) & 0xFF), UInt8(c & 0xFF)]
                return String(bytes: bytes, encoding: .ascii) ?? "?"
            } ?? "?"
            parts.append("\(track.mediaType.rawValue):\(fourCC)")
        }
        return parts.joined(separator: ", ")
    }

    @Test func probe() async throws {
        guard let path = ProcessInfo.processInfo.environment["SPFK_CHAPTER_PROBE_FILE"] else {
            print("PROBE: no SPFK_CHAPTER_PROBE_FILE set, skipping")
            return
        }

        let url = URL(fileURLWithPath: path)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0

        print("PROBE: file \(url.lastPathComponent) size \(size)")
        print("PROBE: before  \(try await trackSummary(url))")
        print("PROBE: audio frames before \((try? AVAudioFile(forReading: url))?.length ?? -1)")

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "One", startTime: 1, endTime: 2),
            ChapterMarker(name: "Two", startTime: 2, endTime: 3),
            ChapterMarker(name: "Three", startTime: 3, endTime: 4),
            ChapterMarker(name: "Four", startTime: 4, endTime: 5),
        ]

        let ok = MP4ChapterUtil.write(markers, to: path)
        print("PROBE: write returned \(ok)")

        let sizeAfter = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0
        print("PROBE: size after \(sizeAfter) delta \(sizeAfter - size)")
        print("PROBE: after   \(try await trackSummary(url))")
        print("PROBE: audio frames after \((try? AVAudioFile(forReading: url))?.length ?? -1)")
    }

    /// The whole post-export sequence on one file, in the order `renderAudioEdit` runs it:
    /// chapter clamp, then `element.save()` with markers dirty.
    @Test func probePipeline() async throws {
        guard let path = ProcessInfo.processInfo.environment["SPFK_PIPELINE_PROBE_FILE"] else {
            print("PIPE: no SPFK_PIPELINE_PROBE_FILE set, skipping")
            return
        }

        let url = URL(fileURLWithPath: path)
        print("PIPE: before  \(try await trackSummary(url))")
        print("PIPE: audio frames before \((try? AVAudioFile(forReading: url))?.length ?? -1)")

        let markers: [ChapterMarker] = [
            ChapterMarker(name: "One", startTime: 1, endTime: 2),
            ChapterMarker(name: "Two", startTime: 2, endTime: 3),
            ChapterMarker(name: "Three", startTime: 3, endTime: 4),
            ChapterMarker(name: "Four", startTime: 4, endTime: 5),
        ]

        print("PIPE: chapters write \(MP4ChapterUtil.write(markers, to: path))")
        print("PIPE: after chapters \(try await trackSummary(url))")

        var desc = try await MetaAudioFileDescription(parsing: url)
        print("PIPE: parsed markers \(desc.markerCollection.markerDescriptions.count)")

        do {
            try desc.save(dirtyFlags: [.metadata, .markers])
            print("PIPE: save ok")
        } catch {
            print("PIPE: save threw \(error)")
        }

        print("PIPE: after save \(try await trackSummary(url))")
        print("PIPE: audio frames after \((try? AVAudioFile(forReading: url))?.length ?? -1)")
    }

    /// The metadata half of `element.save()` — `tagProperties.save(to:)` plus markers.
    @Test func probeMetadataSave() async throws {
        guard let path = ProcessInfo.processInfo.environment["SPFK_META_PROBE_FILE"] else {
            print("META: no SPFK_META_PROBE_FILE set, skipping")
            return
        }

        let url = URL(fileURLWithPath: path)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0

        print("META: file \(url.lastPathComponent) size \(size)")
        print("META: before  \(try await trackSummary(url))")
        print("META: audio frames before \((try? AVAudioFile(forReading: url))?.length ?? -1)")

        var desc = try await MetaAudioFileDescription(parsing: url)
        print("META: parsed fileType \(String(describing: desc.fileType)) isAVPlayable \(desc.isAVPlayable)")

        do {
            try desc.save(dirtyFlags: [.metadata])
            print("META: save ok")
        } catch {
            print("META: save threw \(error)")
        }

        let sizeAfter = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0
        print("META: size after \(sizeAfter) delta \(sizeAfter - size)")
        print("META: after   \(try await trackSummary(url))")
        print("META: audio frames after \((try? AVAudioFile(forReading: url))?.length ?? -1)")
    }
}
