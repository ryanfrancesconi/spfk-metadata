import SPFKAudioBase
import SPFKMetadataC
import SPFKMetadataBase

// swiftformat:disable consecutiveSpaces

extension AudioFileType {
    /// The corresponding `TagFileTypeDef` for this audio format, used to select the correct
    /// TagLib parser. Returns `nil` for formats not supported by TagLib (e.g., `.caf`).
    public var tagType: TagFileTypeDef? {
        switch self {
        case .aac:          return .aac
        case .aifc, .aiff:  return .aiff
        case .flac:         return .flac
        case .ogg:          return .vorbis
        case .m4a:          return .m4a
        case .mp3:          return .mp3
        case .mp4:          return .mp4
        case .opus:         return .opus
        case .wav, .w64:    return .wave
        default:
            return nil
        }
    }

    /// Detects the audio file type from a URL, first checking the path extension,
    /// then falling back to header inspection via TagLib and CoreAudio if the extension is missing.
    public init?(url: URL) {
        let ext = url.pathExtension.lowercased()

        // when the file has no extension
        guard ext != "" else {
            if let value = AudioFileType(parsing: url) {
                self = value
                return
            }
            return nil
        }

        if let value = AudioFileType(pathExtension: ext) {
            self = value
            return
        }

        return nil
    }

    /// Open the file and determine its format via CoreAudio. Note that `TagFile.detectType()` is
    /// faster but only has the types that it supports.
    ///
    /// - Parameter url: URL to an audio file
    /// - Returns: A `MetaAudioFileFormat` or nil
    fileprivate init?(parsing url: URL) {
        // tag lib is faster than CoreAudio so run it first for primary types
        if let tagType = TagFileType.detect(url.path),
           let value = AudioFileType(tagType: tagType) {
            self = value
            return
        }

        // get possible extensions for this URL
        guard let extensions = try? AudioFileType.getExtensions(for: url) else { return nil }

        for ext in extensions {
            for item in Self.allCases where item.pathExtension == ext {
                self = item
                return
            }
        }

        return nil
    }

    /// Creates an `AudioFileType` from a TagLib file type definition.
    public init?(tagType: TagFileTypeDef) {
        for item in Self.allCases where item.tagType == tagType {
            self = item
            return
        }

        return nil
    }
}

// swiftformat:enable consecutiveSpaces
