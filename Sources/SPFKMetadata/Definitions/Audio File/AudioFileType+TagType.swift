// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
internal import SPFKMetadataC

// swiftformat:disable consecutiveSpaces

extension AudioFileType {
    /// Nil for a format TagLib doesn't parse (`.caf`, `.w64`).
    var tagType: TagFileTypeDef? {
        switch self {
        case .aac:  .aac
        case .aifc,
             .aiff: .aiff
        case .flac: .flac
        case .ogg:  .vorbis
        case .m4a:  .m4a
        case .mka,
             .mkv:  .matroska
        case .mp3:  .mp3
        case .mp4:  .mp4
        case .opus: .opus
        case .webm: .webm
        case .wav:  .wave
        default:
            nil
        }
    }

    /// By extension; a file without one is sniffed.
    public init?(url: URL) {
        let ext = url.pathExtension.lowercased()

        guard let value = ext.isEmpty ? AudioFileType(parsing: url) : AudioFileType(pathExtension: ext) else {
            return nil
        }

        self = value
    }

    /// TagLib's header check first, as it is faster; Core Audio covers what TagLib doesn't know.
    private init?(parsing url: URL) {
        if let tagType = TagFileType.detect(url.path),
           let value = AudioFileType(tagType: tagType)
        {
            self = value
            return
        }

        guard let extensions = try? AudioFileType.getExtensions(for: url) else { return nil }

        for ext in extensions {
            for item in Self.allCases where item.pathExtension == ext {
                self = item
                return
            }
        }

        return nil
    }

    init?(tagType: TagFileTypeDef) {
        for item in Self.allCases where item.tagType == tagType {
            self = item
            return
        }

        return nil
    }
}

// swiftformat:enable consecutiveSpaces
