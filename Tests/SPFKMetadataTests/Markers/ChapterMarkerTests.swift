// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

@Suite(.serialized)
class ChapterMarkerTests: BinTestCase {
    func getChapters(in url: URL) async throws -> [ChapterMarker] {
        let chapters = try await ChapterParser.parse(url: url)
        Log.debug(chapters.map { ($0.name ?? "nil") + " @ \($0.startTime)" })
        return chapters
    }

    @Test func parseMarkers_mp4() async throws {
        let markers = try await getChapters(in: TestBundleResources.shared.tabla_mp4)
        let names = markers.compactMap(\.name)
        let times = markers.map(\.startTime)

        #expect(markers.count == 5)
        #expect(names == ["Marker 0", "Marker 1", "Marker 2", "Marker 3", "Marker 4"])
        #expect(times == [0.0, 1.0, 2.0, 3.0, 4.0])
    }

    @Test func parseMarkers_m4a() async throws {
        let markers = try await getChapters(in: TestBundleResources.shared.tabla_m4a)
        let names = markers.compactMap(\.name)
        let times = markers.map(\.startTime)

        #expect(markers.count == 5)
        #expect(names == ["Marker 0", "Marker 1", "Marker 2", "Marker 3", "Marker 4"])
        #expect(times == [0.0, 1.0, 2.0, 3.0, 4.0])
    }
    
    @Test func writeAndReadChaptersM4A() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_m4a)
        
        let w_markers: [ChapterMarker] = [
            ChapterMarker(name: "Marker 1", startTime: 1, endTime: 2),
            ChapterMarker(name: "Marker 2", startTime: 2, endTime: 3),
            ChapterMarker(name: "Marker 3", startTime: 3, endTime: 4),
        ]
        
        #expect(MP4ChapterUtil.writeChapters(w_markers, to: tmpfile.path))
        
        let r_markers = try await getChapters(in: tmpfile)
        let names = r_markers.compactMap(\.name)
        let times = r_markers.map(\.startTime)

        #expect(r_markers.count == 4)
        // empty marker at 0 is placeholder dummy added to correctly offset subsequent markers
        #expect(names == ["", "Marker 1", "Marker 2", "Marker 3"])
        #expect(times == [0.0, 1.0, 2.0, 3.0])
        
    }
}
