import Foundation
import SPFKMetadataBase
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

// MARK: - TagFrameKey protocol / ID3FrameKey

struct ID3FrameKeyTests {
    @Test func valueMapping() {
        #expect(ID3FrameKey.title.value == "TIT2")
        #expect(ID3FrameKey.album.value == "TALB")
        #expect(ID3FrameKey.artist.value == "TPE1")
        #expect(ID3FrameKey.bpm.value == "TBPM")
        #expect(ID3FrameKey.comment.value == "COMM")
        #expect(ID3FrameKey.trackNumber.value == "TRCK")
        #expect(ID3FrameKey.userDefined.value == "TXXX")
        #expect(ID3FrameKey.picture.value == "APIC")
    }

    @Test func initFromValue() {
        #expect(ID3FrameKey(value: "TIT2") == .title)
        #expect(ID3FrameKey(value: "TALB") == .album)
        #expect(ID3FrameKey(value: "TPE1") == .artist)
        #expect(ID3FrameKey(value: "TXXX") == .userDefined)
        #expect(ID3FrameKey(value: "INVALID") == nil)
    }

    @Test func taglibKey() {
        // default TagFrameKey protocol: rawValue.uppercased()
        #expect(ID3FrameKey.title.taglibKey == "TITLE")
        #expect(ID3FrameKey.album.taglibKey == "ALBUM")
        #expect(ID3FrameKey.bpm.taglibKey == "BPM")
    }

    @Test func displayName() {
        #expect(ID3FrameKey.albumArtist.displayName == "Album Artist")
        #expect(ID3FrameKey.trackNumber.displayName == "Track Number")
        #expect(ID3FrameKey.bpm.displayName == "Bpm")
    }

    @Test func initFromDisplayName() {
        #expect(ID3FrameKey(displayName: "Title") == .title)
        #expect(ID3FrameKey(displayName: "Album") == .album)
        #expect(ID3FrameKey(displayName: "Not Real") == nil)
    }

    @Test func initFromTaglibKey() {
        #expect(ID3FrameKey(taglibKey: "TITLE") == .title)
        #expect(ID3FrameKey(taglibKey: "ALBUM") == .album)
        #expect(ID3FrameKey(taglibKey: "NOPE") == nil)
    }

    @Test func comparable() {
        #expect(ID3FrameKey.album < ID3FrameKey.title)
        #expect(!(ID3FrameKey.title < ID3FrameKey.title))
    }

    @Test func arranger_remixer_shareValue() {
        // both arranger and remixer map to TPE4
        #expect(ID3FrameKey.arranger.value == "TPE4")
        #expect(ID3FrameKey.remixer.value == "TPE4")
    }

    @Test func codable() throws {
        let encoded = try JSONEncoder().encode(ID3FrameKey.title)
        let decoded = try JSONDecoder().decode(ID3FrameKey.self, from: encoded)
        #expect(decoded == .title)
    }
}

// MARK: - InfoFrameKey

struct InfoFrameKeyTests {
    @Test func valueMapping() {
        #expect(InfoFrameKey.title.value == "INAM")
        #expect(InfoFrameKey.artist.value == "IART")
        #expect(InfoFrameKey.comment.value == "ICMT")
        #expect(InfoFrameKey.copyright.value == "ICOP")
        #expect(InfoFrameKey.genre.value == "IGNR")
        #expect(InfoFrameKey.keywords.value == "IKEY")
        #expect(InfoFrameKey.product.value == "IPRD")
    }

    @Test func initFromValue() {
        #expect(InfoFrameKey(value: "INAM") == .title)
        #expect(InfoFrameKey(value: "IART") == .artist)
        #expect(InfoFrameKey(value: "INVALID") == nil)
    }

    @Test func comparable() {
        #expect(InfoFrameKey.artist < InfoFrameKey.title)
    }

    @Test func trackNumberVariants() {
        #expect(InfoFrameKey.trackNumber1.value == "ITRK")
        #expect(InfoFrameKey.trackNumber2.value == "TRCK")
        #expect(InfoFrameKey.trackNumber3.value == "IPRT")
    }

    @Test func codable() throws {
        let encoded = try JSONEncoder().encode(InfoFrameKey.genre)
        let decoded = try JSONDecoder().decode(InfoFrameKey.self, from: encoded)
        #expect(decoded == .genre)
    }
}

// MARK: - TagFileTypeDef

struct TagFileTypeDefTests {
    @Test func allCases() {
        let cases = TagFileTypeDef.allCases
        #expect(cases.count == 9)
        #expect(cases.contains(.mp3))
        #expect(cases.contains(.wave))
        #expect(cases.contains(.flac))
        #expect(cases.contains(.aiff))
        #expect(cases.contains(.m4a))
        #expect(cases.contains(.mp4))
        #expect(cases.contains(.aac))
        #expect(cases.contains(.opus))
        #expect(cases.contains(.vorbis))
    }
}
