// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
internal import SPFKMetadataC

/// The BEXT and iXML chunks of WAV and FLAC files, read and written apart from the tags.
///
/// A write changes only its own chunk; an edited BEXT keeps the stored bytes of every field it leaves alone.
public enum ProductionChunks {}

// MARK: - BEXT

extension ProductionChunks {
    /// Nil when the file has none, can't be opened, or is not WAV or FLAC.
    public static func readBEXT(from url: URL, fileType: AudioFileType) -> BEXTDescription? {
        switch fileType {
        case .wav:
            let file = WaveFileC(path: url.path)
            guard file.loadTags(), let info = file.bextDescriptionC else { return nil }
            return BEXTDescription(info: info)

        case .flac:
            let file = FlacFileC(path: url.path)
            guard file.load() else { return nil }
            return file.bextDescription

        default:
            return nil
        }
    }

    public static func writeBEXT(_ bext: BEXTDescription, to url: URL, fileType: AudioFileType) throws {
        switch fileType {
        case .wav:
            let file = WaveFileC.chunkWriter(path: url.path)
            file.bextDescriptionC = bext.bextDescriptionC
            file.bextNeedsSave = true

            guard file.save() else { throw MetadataError.writeFailed(.bext, url) }

        case .flac:
            let file = FlacFileC(path: url.path)
            file.bextDescription = bext
            file.iXMLNeedsSave = false

            guard file.save() else { throw MetadataError.writeFailed(.bext, url) }

        default:
            throw MetadataError.unsupportedFormat(fileType.utType, .bext)
        }
    }
}

// MARK: - iXML

extension ProductionChunks {
    /// The chunk's text as stored. Nil when the file has none, can't be opened, or is not WAV or FLAC.
    public static func readIXML(from url: URL, fileType: AudioFileType) -> String? {
        switch fileType {
        case .wav:
            let file = WaveFileC(path: url.path)
            guard file.loadTags() else { return nil }
            return file.iXML

        case .flac:
            let file = FlacFileC(path: url.path)
            guard file.load() else { return nil }
            return file.iXML

        default:
            return nil
        }
    }

    public static func writeIXML(_ xml: String, to url: URL, fileType: AudioFileType) throws {
        switch fileType {
        case .wav:
            let file = WaveFileC.chunkWriter(path: url.path)
            file.iXML = xml
            file.iXMLNeedsSave = true

            guard file.save() else { throw MetadataError.writeFailed(.ixml, url) }

        case .flac:
            let file = FlacFileC(path: url.path)
            file.iXML = xml
            file.bextNeedsSave = false

            guard file.save() else { throw MetadataError.writeFailed(.ixml, url) }

        default:
            throw MetadataError.unsupportedFormat(fileType.utType, .ixml)
        }
    }
}

// MARK: - Both

extension ProductionChunks {
    /// Removes BEXT and iXML in one save; a file with neither is left unwritten. Throws
    /// `removeFailed(.bext, url)` for either chunk.
    public static func removeAll(from url: URL, fileType: AudioFileType) throws {
        switch fileType {
        case .wav:
            let stored = WaveFileC(path: url.path)
            guard stored.loadTags() else { throw MetadataError.removeFailed(.bext, url) }
            guard stored.bextDescriptionC != nil || stored.iXML != nil else { return }

            let file = WaveFileC.chunkWriter(path: url.path)
            file.bextNeedsSave = true
            file.iXMLNeedsSave = true

            guard file.save() else { throw MetadataError.removeFailed(.bext, url) }

        case .flac:
            let file = FlacFileC(path: url.path)
            guard file.load() else { throw MetadataError.removeFailed(.bext, url) }
            guard file.bextDescriptionC != nil || file.iXML != nil else { return }

            file.bextDescriptionC = nil
            file.iXML = nil

            guard file.save() else { throw MetadataError.removeFailed(.bext, url) }

        default:
            throw MetadataError.unsupportedFormat(fileType.utType, .bext)
        }
    }
}

private extension WaveFileC {
    /// A writer that changes nothing until a component's flag is set.
    static func chunkWriter(path: String) -> WaveFileC {
        let file = WaveFileC(path: path)
        file.tagsNeedsSave = false
        file.bextNeedsSave = false
        file.iXMLNeedsSave = false
        file.markersNeedsSave = false
        file.artworkNeedsSave = false
        return file
    }
}
