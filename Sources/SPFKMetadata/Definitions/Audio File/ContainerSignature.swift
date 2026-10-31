// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import UniformTypeIdentifiers

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

    /// What a file's content is, as a type and the extension to give it.
    struct Content: Equatable {
        let container: ContainerSignature
        let type: UTType
        let pathExtension: String
    }

    /// What a file's content proves it to be when its extension names another container; nil when
    /// they agree, or when either is not one this judges.
    static func mismatchedContent(of url: URL) throws -> Content? {
        guard let named = ContainerSignature(pathExtension: url.pathExtension) else { return nil }

        let handle = try FileHandle(forReadingFrom: url)
        let header = try handle.read(upToCount: 12) ?? Data()
        try handle.close()

        guard let content = content(of: header), content.container != named else { return nil }
        return content
    }

    /// `header` is the first 12 bytes of a file. The extension is chosen here rather than taken from
    /// the type, whose preferred extension for MPEG-4 audio is `mp4`, not `m4a`.
    static func content(of header: Data) -> Content? {
        guard header.count >= 12 else { return nil }
        let bytes = [UInt8](header)
        let text = { (offset: Int) in String(decoding: bytes[offset ..< offset + 4], as: UTF8.self) }

        switch (text(0), text(8)) {
        case ("RIFF", "WAVE"), ("RF64", "WAVE"), ("BW64", "WAVE"):
            return Content(container: .wave, type: .wav, pathExtension: "wav")
        case ("FORM", "AIFF"), ("FORM", "AIFC"):
            return Content(container: .aiff, type: .aiff, pathExtension: "aif")
        default:
            break
        }

        if text(4) == "ftyp" {
            return switch text(8) {
            case "M4A ": Content(container: .mp4, type: .mpeg4Audio, pathExtension: "m4a")
            case "M4B ": Content(container: .mp4, type: .mpeg4Audio, pathExtension: "m4b")
            default: Content(container: .mp4, type: .mpeg4Movie, pathExtension: "mp4")
            }
        }

        switch text(0) {
        case "fLaC":
            return Content(container: .flac, type: UTType(filenameExtension: "flac") ?? .audio, pathExtension: "flac")
        case "OggS":
            return Content(container: .ogg, type: UTType(filenameExtension: "ogg") ?? .audio, pathExtension: "ogg")
        default:
            break
        }

        if bytes.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) {
            return Content(container: .matroska, type: UTType(filenameExtension: "mkv") ?? .movie, pathExtension: "mkv")
        }

        return nil
    }
}
