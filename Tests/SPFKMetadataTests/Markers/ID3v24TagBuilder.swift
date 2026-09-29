// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// Hand-built ID3v2.4 frames, for tag layouts no fixture or writer on this machine produces.
enum ID3v24TagBuilder {
    enum BuildError: Error {
        case notID3v2(URL)
    }

    static func syncsafe(_ value: Int) -> Data {
        Data([
            UInt8((value >> 21) & 0x7F),
            UInt8((value >> 14) & 0x7F),
            UInt8((value >> 7) & 0x7F),
            UInt8(value & 0x7F),
        ])
    }

    static func bigEndian(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }

    /// 4-byte ID, syncsafe size, two zero flag bytes, then `body`.
    static func frame(id: String, body: Data) -> Data {
        Data(id.utf8) + syncsafe(body.count) + Data([0, 0]) + body
    }

    /// `TIT2` marked Latin-1 but holding `text`'s UTF-8 bytes.
    static func tit2(_ text: String) -> Data {
        frame(id: "TIT2", body: Data([0]) + Data(text.utf8))
    }

    /// `TIT2` with Latin-1 encoding; `text` must be representable in Latin-1.
    static func tit2(latin1 text: String) -> Data {
        frame(id: "TIT2", body: Data([0]) + (text.data(using: .isoLatin1) ?? Data()))
    }

    /// `TIT2` with UTF-16 encoding: a little-endian BOM, then the text.
    static func tit2(utf16 text: String) -> Data {
        let units = text.utf16.flatMap { unit in [UInt8(unit & 0xFF), UInt8(unit >> 8)] }
        return frame(id: "TIT2", body: Data([1, 0xFF, 0xFE]) + Data(units))
    }

    /// `WXXX` with Latin-1 encoding.
    static func wxxx(description: String, url: String) -> Data {
        frame(id: "WXXX", body: Data([0]) + Data(description.utf8) + Data([0]) + Data(url.utf8))
    }

    /// Start and end offsets are written as `0xFFFFFFFF` (unused).
    static func chap(elementID: String, startMs: UInt32, endMs: UInt32, embedded: [Data]) -> Data {
        chap(elementID: Data(elementID.utf8), startMs: startMs, endMs: endMs, embedded: embedded)
    }

    /// `elementID` is written as given, then a NUL.
    static func chap(elementID: Data, startMs: UInt32, endMs: UInt32, embedded: [Data]) -> Data {
        var body = elementID + Data([0])
        body += bigEndian(startMs) + bigEndian(endMs)
        body += bigEndian(.max) + bigEndian(.max)
        body += embedded.reduce(Data(), +)
        return frame(id: "CHAP", body: body)
    }

    /// Replaces the file's leading ID3v2 tag with a v2.4 tag holding `frames`.
    static func replaceTag(in url: URL, with frames: [Data]) throws {
        let file = try Data(contentsOf: url)
        let header = file.prefix(10)

        guard header.count == 10, header.prefix(3) == Data("ID3".utf8) else {
            throw BuildError.notID3v2(url)
        }

        let bytes = [UInt8](header)
        let tagSize = bytes[6...9].reduce(0) { ($0 << 7) | Int($1 & 0x7F) }
        let footerSize = bytes[5] & 0x10 != 0 ? 10 : 0
        let audio = file.dropFirst(10 + tagSize + footerSize)

        let tagBody = frames.reduce(Data(), +)
        let newHeader = Data("ID3".utf8) + Data([4, 0, 0]) + syncsafe(tagBody.count)

        try (newHeader + tagBody + audio).write(to: url)
    }
}
