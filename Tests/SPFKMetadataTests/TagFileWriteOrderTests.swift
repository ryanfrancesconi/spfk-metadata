// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// A tag write whose rating cannot be stored still restores what the write cleared.
@Suite(.tags(.file))
final class TagFileWriteOrderTests: BinTestCase {
    /// A TrueAudio file: a container TagLib writes tags and pictures to (ID3v2) that has no rating
    /// store, so a rating above zero fails to write.
    private func trueAudioFile() throws -> URL {
        var header = Data("TTA1".utf8)

        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) }
        }

        append(UInt16(1)) // PCM
        append(UInt16(1)) // channels
        append(UInt16(16)) // bits per sample
        append(UInt32(44100))
        append(UInt32(0)) // samples
        append(UInt32(0)) // CRC
        header.append(Data(count: 64))

        let url = bin.appendingPathComponent("no-rating-store.tta")
        try header.write(to: url)
        return url
    }

    @Test func aFailedRatingWriteKeepsTheArtwork() throws {
        let url = try trueAudioFile()
        let picture = try TagPictureRef.parsing(url: TestBundleResources.shared.mp3_id3)
        #expect(TagPicture.write(picture, path: url.path))
        #expect(TagPicture(path: url.path)?.pictureRef != nil)

        let session = try #require(MetadataSaveSession(path: url.path))
        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = ["TITLE": "Edited", "RATING": "4"]

        #expect(tagFile.write(toFileRef: session.fileRef) == false)
        #expect(session.save())

        let onDisk = TagFile(path: url.path)
        #expect(onDisk.load())
        #expect(onDisk.dictionary?["TITLE"] as? String == "Edited")
        #expect(TagPicture(path: url.path)?.pictureRef != nil)
    }
}
