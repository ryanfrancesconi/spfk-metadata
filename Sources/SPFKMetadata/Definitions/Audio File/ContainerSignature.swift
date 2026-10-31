// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// The container a file's first bytes prove it to be, for formats with an unambiguous signature.
///
/// MPEG audio and ADTS have none, so content is only ever proven to be one of these; an MP3 named
/// `.m4a` is caught by TagLib instead, which falls back to the content when MP4 rejects it.
enum ContainerSignature: Equatable {
    case wave, aiff, mp4, flac, ogg, matroska, mpeg

    /// The container an extension names, nil for one this does not judge.
    init?(pathExtension: String) {
        switch pathExtension.lowercased() {
        case "wav", "wave", "bwf": self = .wave
        case "aif", "aiff", "aifc": self = .aiff
        case "m4a", "m4b", "m4r", "m4p", "mp4", "m4v", "mov", "3gp": self = .mp4
        case "flac": self = .flac
        case "ogg", "oga", "opus", "spx": self = .ogg
        case "mkv", "mka", "webm", "mk3d": self = .matroska
        case "mp3", "mp2", "aac", "mpga": self = .mpeg
        default: return nil
        }
    }

    /// What a file's content is, and the extension to give it.
    struct Content: Equatable {
        let container: ContainerSignature
        let pathExtension: String
    }

    /// What a file's content proves it to be when its extension names another container; nil when
    /// they agree, or when either is not one this judges.
    static func mismatchedContent(of url: URL) throws -> Content? {
        guard let named = ContainerSignature(pathExtension: url.pathExtension) else { return nil }

        let header = try header(of: url)

        guard let content = content(of: header), content.container != named else { return nil }

        // TagLib reads a WAVE holding MPEG audio as MPEG when it is named so.
        if named == .mpeg, content.container == .wave, holdsMPEGAudio(header) { return nil }

        return content
    }

    /// The first 24 bytes after any ID3v2 tag, where TagLib's content detection looks.
    static func header(of url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        var header = try handle.read(upToCount: 24) ?? Data()

        if header.count >= 10, header.starts(with: Data("ID3".utf8)) {
            let bytes = [UInt8](header)
            let size = bytes[6 ... 9].reduce(0) { $0 << 7 | Int($1 & 0x7F) }
            let footer = bytes[5] & 0x10 != 0 ? 10 : 0
            try handle.seek(toOffset: UInt64(10 + size + footer))
            header = try handle.read(upToCount: 24) ?? Data()
        }

        try handle.close()
        return header
    }

    /// Whether `header` is a WAVE whose format tag is MPEG (0x0050) or MPEG Layer 3 (0x0055).
    static func holdsMPEGAudio(_ header: Data) -> Bool {
        guard header.count >= 22 else { return false }
        let bytes = [UInt8](header)
        guard String(decoding: bytes[12 ..< 16], as: UTF8.self) == "fmt " else { return false }

        let format = UInt16(bytes[20]) | UInt16(bytes[21]) << 8
        return format == 0x0050 || format == 0x0055
    }

    /// `header` is the first bytes of a file after any ID3v2 tag.
    static func content(of header: Data) -> Content? {
        guard header.count >= 12 else { return nil }
        let bytes = [UInt8](header)
        let text = { (offset: Int) in String(decoding: bytes[offset ..< offset + 4], as: UTF8.self) }

        switch (text(0), text(8)) {
        case ("RIFF", "WAVE"), ("RF64", "WAVE"), ("BW64", "WAVE"):
            return Content(container: .wave, pathExtension: "wav")
        case ("FORM", "AIFF"), ("FORM", "AIFC"):
            return Content(container: .aiff, pathExtension: "aif")
        default:
            break
        }

        if text(4) == "ftyp" {
            return switch text(8) {
            case "M4A ": Content(container: .mp4, pathExtension: "m4a")
            case "M4B ": Content(container: .mp4, pathExtension: "m4b")
            default: Content(container: .mp4, pathExtension: "mp4")
            }
        }

        switch text(0) {
        case "fLaC":
            return Content(container: .flac, pathExtension: "flac")
        case "OggS":
            return Content(container: .ogg, pathExtension: "ogg")
        default:
            break
        }

        if bytes.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) {
            return Content(container: .matroska, pathExtension: "mkv")
        }

        return nil
    }
}
