// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// ID3v2.3 frames and tags: plain big-endian frame sizes, and no UTF-8 — text is Latin-1 where it
/// fits, else UTF-16 with a byte-order mark.
extension ID3v24TagBuilder {
    /// 4-byte ID, big-endian size, two zero flag bytes, then `body`.
    static func version3Frame(id: String, body: Data) -> Data {
        Data(id.utf8) + bigEndian(UInt32(body.count)) + Data([0, 0]) + body
    }

    /// The encoding byte for `strings`, and each string encoded with its terminator.
    static func version3Text(_ strings: [String]) -> (encoding: UInt8, terminated: [Data]) {
        let latin1 = strings.allSatisfy { $0.unicodeScalars.allSatisfy { $0.value <= 0xFF } }

        if latin1 {
            return (0, strings.map { Data($0.unicodeScalars.map { UInt8($0.value) }) + Data([0]) })
        }

        return (1, strings.map { string in
            let units = string.utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] }
            return Data([0xFF, 0xFE] + units + [0, 0])
        })
    }

    /// A text frame; several values are NUL-separated, as TagLib reads them in either version.
    static func version3TextFrame(id: String, values: [String]) -> Data {
        let (encoding, terminated) = version3Text(values)
        return version3Frame(id: id, body: Data([encoding]) + dropLastTerminator(terminated.reduce(Data(), +), encoding: encoding))
    }

    static func version3UserText(description: String, values: [String]) -> Data {
        let (encoding, terminated) = version3Text([description] + values)
        return version3Frame(id: "TXXX", body: Data([encoding]) + dropLastTerminator(terminated.reduce(Data(), +), encoding: encoding))
    }

    /// `COMM` or `USLT`.
    static func version3Comment(id: String, language: String, description: String, text: String) -> Data {
        let (encoding, terminated) = version3Text([description, text])
        return version3Frame(id: id, body: Data([encoding]) + Data(language.utf8.prefix(3)) + terminated[0]
            + dropLastTerminator(terminated[1], encoding: encoding))
    }

    static func version3UserURL(description: String, url: String) -> Data {
        let (encoding, terminated) = version3Text([description])
        return version3Frame(id: "WXXX", body: Data([encoding]) + terminated[0] + Data(url.utf8))
    }

    static func version3Popularimeter(email: String, rating: UInt8, counter: UInt32) -> Data {
        version3Frame(id: "POPM", body: Data(email.utf8) + Data([0, rating]) + bigEndian(counter))
    }

    static func version3PlayCount(_ count: UInt32) -> Data {
        version3Frame(id: "PCNT", body: bigEndian(count))
    }

    /// `PRIV` or `UFID`: a Latin-1 owner, then the data.
    static func version3Owned(id: String, owner: String, data: Data) -> Data {
        version3Frame(id: id, body: Data(owner.utf8) + Data([0]) + data)
    }

    static func version3GeneralObject(mimeType: String, fileName: String, description: String, object: Data) -> Data {
        let (encoding, terminated) = version3Text([fileName, description])
        return version3Frame(id: "GEOB", body: Data([encoding]) + Data(mimeType.utf8) + Data([0]) + terminated.reduce(Data(), +) + object)
    }

    static func version3Picture(mimeType: String, pictureType: UInt8, description: String, data: Data) -> Data {
        let (encoding, terminated) = version3Text([description])
        return version3Frame(id: "APIC", body: Data([encoding]) + Data(mimeType.utf8) + Data([0, pictureType]) + terminated[0] + data)
    }

    /// `flags` bit `0x02` marks the top-level table, `0x01` an ordered one.
    static func version3TableOfContents(elementID: String, flags: UInt8, children: [String]) -> Data {
        let body = Data(elementID.utf8) + Data([0, flags, UInt8(children.count)])
            + children.map { Data($0.utf8) + Data([0]) }.reduce(Data(), +)
        return version3Frame(id: "CTOC", body: body)
    }

    /// The reader decodes element IDs as Latin-1; this restores their bytes.
    private static func latin1(_ string: String) -> Data {
        Data(string.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) })
    }

    private static func dropLastTerminator(_ data: Data, encoding: UInt8) -> Data {
        data.dropLast(encoding == 0 ? 1 : 2)
    }

    // MARK: - Re-rendering a v2.4 tag

    /// `frame` from a tag of `majorVersion`, as a v2.3 frame. Text is re-encoded, `CHAP` and `CTOC`
    /// sub-frames re-rendered, a 4-digit `TDRC`/`TDOR` and `TIPL` given their v2.3 IDs; any other
    /// body is copied as it is.
    static func version3Frame(rendering frame: ID3v2Frames.Frame, from majorVersion: UInt8) throws -> Data {
        let body = frame.body

        switch frame.id {
        case "TXXX":
            let text = try ID3v2Frames.UserText(body)
            return version3UserText(description: text.description, values: text.values)

        case "COMM", "USLT":
            let comment = try ID3v2Frames.Comment(body)
            return version3Comment(id: frame.id, language: comment.language, description: comment.description, text: comment.text)

        case "WXXX":
            let link = try ID3v2Frames.UserURL(body)
            return version3UserURL(description: link.description, url: link.url)

        case "APIC":
            let picture = try ID3v2Frames.Picture(body)
            return version3Picture(mimeType: picture.mimeType, pictureType: picture.pictureType, description: picture.description, data: picture.data)

        case "GEOB":
            let object = try ID3v2Frames.GeneralObject(body)
            return version3GeneralObject(mimeType: object.mimeType, fileName: object.fileName, description: object.description, object: object.object)

        case "CHAP":
            let chapter = try ID3v2Frames.Chapter(body, majorVersion: majorVersion)
            let subframes = try chapter.subframes.map { try version3Frame(rendering: $0, from: majorVersion) }
            let chapterBody = latin1(chapter.elementID) + Data([0])
                + [chapter.startTime, chapter.endTime, chapter.startOffset, chapter.endOffset].map(bigEndian).reduce(Data(), +)
                + subframes.reduce(Data(), +)
            return version3Frame(id: "CHAP", body: chapterBody)

        case "CTOC":
            let toc = try ID3v2Frames.TableOfContents(body, majorVersion: majorVersion)
            let flags: UInt8 = (toc.isTopLevel ? 0x02 : 0) | (toc.isOrdered ? 0x01 : 0)
            let subframes = try toc.subframes.map { try version3Frame(rendering: $0, from: majorVersion) }
            let tocBody = latin1(toc.elementID) + Data([0, flags, UInt8(toc.children.count)])
                + toc.children.map { latin1($0) + Data([0]) }.reduce(Data(), +) + subframes.reduce(Data(), +)
            return version3Frame(id: "CTOC", body: tocBody)

        case let id where id.hasPrefix("T"):
            let values = try ID3v2Frames.textValues(body)
            return version3TextFrame(id: version3ID(id, values: values), values: values)

        default:
            return version3Frame(id: frame.id, body: body)
        }
    }

    private static func version3ID(_ id: String, values: [String]) -> String {
        let isYear = values.count == 1 && values[0].count == 4 && values[0].allSatisfy(\.isNumber)

        switch id {
        case "TDRC" where isYear: return "TYER"
        case "TDOR" where isYear: return "TORY"
        case "TIPL": return "IPLS"
        default: return id
        }
    }

    /// Replaces the file's leading ID3v2 tag with a v2.3 tag of `frames` and no padding, and
    /// removes a trailing ID3v1 tag.
    static func replaceTagWithVersion3(in url: URL, frames: [Data]) throws {
        var file = try Data(contentsOf: url)
        let header = [UInt8](file.prefix(10))

        guard header.count == 10, header.starts(with: Array("ID3".utf8)) else {
            throw BuildError.notID3v2(url)
        }

        let tagSize = header[6 ... 9].reduce(0) { ($0 << 7) | Int($1 & 0x7F) }
        let footerSize = header[5] & 0x10 != 0 ? 10 : 0
        file = Data(file.dropFirst(10 + tagSize + footerSize))

        if file.count >= 128, file.suffix(128).starts(with: Data("TAG".utf8)) {
            file.removeLast(128)
        }

        try (version3Tag(frames: frames) + file).write(to: url)
    }

    /// An ID3v2.3 tag of `frames` with no padding.
    static func version3Tag(frames: [Data]) -> Data {
        let tagBody = frames.reduce(Data(), +)
        return Data("ID3".utf8) + Data([3, 0, 0]) + syncsafe(tagBody.count) + tagBody
    }
}
