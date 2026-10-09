// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// An MP3 save keeps the ID3v2 version the file has, unless the tag holds a frame that version
/// cannot store, and adds no ID3v1 tag the file did not have.
@Suite(.tags(.file))
final class MP3TagVersionTests: BinTestCase {
    /// `tabla.mp3` with a v2.3 tag holding a title and, when given, a `TMOO`.
    private func version3File(mood: String?) throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        var frames = [ID3v24TagBuilder.version3TextFrame(id: "TIT2", values: ["Version 3"])]
        if let mood { frames.append(ID3v24TagBuilder.version3TextFrame(id: "TMOO", values: [mood])) }
        try ID3v24TagBuilder.replaceTagWithVersion3(in: url, frames: frames)
        return url
    }

    private func saveTitle(_ title: String, to url: URL) async throws {
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = title
        try description.save(dirtyFlags: [.tags])
    }

    @Test func aVersion3TagStaysVersion3WithoutAnID3v1Tag() async throws {
        let url = try version3File(mood: nil)
        #expect(try ID3v2Frames.hasID3v1(in: url) == false)

        try await saveTitle("Saved", to: url)

        #expect(try ID3v2Frames.majorVersion(in: url) == 3)
        #expect(try ID3v2Frames.hasID3v1(in: url) == false)
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "Saved")
    }

    /// ID3v2.3 has no `TMOO`; writing v2.3 would drop the mood.
    @Test func aVersion3TagHoldingAMoodIsWrittenAsVersion4() async throws {
        let url = try version3File(mood: "Druids")

        try await saveTitle("Saved", to: url)

        #expect(try ID3v2Frames.majorVersion(in: url) == 4)
        #expect(try ID3v2Frames.tag(in: url)?.frames.contains { $0.id == "TMOO" } == true)
    }
}
