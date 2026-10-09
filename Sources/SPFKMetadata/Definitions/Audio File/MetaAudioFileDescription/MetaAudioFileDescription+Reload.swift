// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AEXML
import Foundation
import SPFKBase
import SPFKMetadataBase
internal import SPFKMetadataC

extension MetaAudioFileDescription {
    /// Re-reads the file's tags and, for WAV and FLAC, its BEXT and iXML, leaving markers, artwork,
    /// the audio format and URL properties as they are.
    ///
    /// For after a write that changes those fields behind this description's back -- an XMP write
    /// on WAV, AIFF or MP3 exports into them.
    public mutating func reloadEmbeddedMetadata() throws {
        switch fileType {
        case .wav:
            let waveFile = WaveFileC(path: url.path)

            guard waveFile.load() else {
                throw NSError(description: "Failed to load wave file at \(url.path)")
            }

            let audioProperties = tagProperties.audioProperties
            tagProperties = TagProperties()
            tagProperties.audioProperties = audioProperties
            iXMLMetadata = nil
            bextDescription = nil

            readEmbeddedMetadata(from: waveFile)

        default:
            let audioProperties = tagProperties.audioProperties
            tagProperties = try TagProperties(url: url)
            tagProperties.audioProperties = tagProperties.audioProperties ?? audioProperties

            if fileType == .flac {
                let flacFile = FlacFileC(path: url.path)

                guard flacFile.load() else {
                    throw NSError(description: "Failed to load FLAC file at \(url.path)")
                }

                iXMLMetadata = nil
                bextDescription = nil
                readEmbeddedMetadata(from: flacFile)
            }
        }
    }

    /// iXML, BEXT, and the INFO and ID3 tags. Adds to `tagProperties` rather than replacing it.
    mutating func readEmbeddedMetadata(from waveFile: WaveFileC) {
        if let xml = waveFile.iXML {
            iXMLMetadata = normalizedIXML(xml)
        }

        bextDescription = waveFile.bextDescription?.validated()

        tagProperties.load(waveFile: waveFile)
    }

    /// FLAC's iXML and BEXT APPLICATION blocks. BEXT falls back to iXML's `<BEXT>` element, where
    /// Sequoia writes it.
    mutating func readEmbeddedMetadata(from flacFile: FlacFileC) {
        if let xml = flacFile.iXML {
            iXMLMetadata = normalizedIXML(xml)
        }

        if let bext = flacFile.bextDescription?.validated() {
            bextDescription = bext
        } else if let xml = flacFile.iXML,
                  let ixml = try? IXMLMetadata(xml: xml),
                  let bext = BEXTDescription(ixmlMetadata: ixml)
        {
            bextDescription = bext.validated()
        }
    }

    /// Re-serialized for consistent formatting, keeping each value's text exactly. A chunk that
    /// won't parse is kept as read.
    private func normalizedIXML(_ xml: String) -> String {
        var options = AEXMLOptions()
        options.parserSettings.shouldTrimWhitespace = false

        do {
            return try AEXMLDocument(xml: xml, options: options).xml
        } catch {
            Log.error("Unparseable iXML in \(url.lastPathComponent), kept as read: \(error)")
            return xml
        }
    }
}
