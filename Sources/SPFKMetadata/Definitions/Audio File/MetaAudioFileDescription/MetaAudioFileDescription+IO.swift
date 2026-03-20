// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AEXML
import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKUtils

extension MetaAudioFileDescription {
    /// Reads all metadata from the audio file at the given URL.
    ///
    /// For WAV files, all properties (format, tags, BEXT, iXML, artwork, markers)
    /// are read via TagLib + AudioToolbox — `AVAudioFile` is not opened.
    /// For other formats, `AVAudioFile` provides format properties while TagLib handles tags.
    ///
    /// - Parameter url: URL to the audio file to parse.
    /// - Throws: If the file cannot be opened or its format is unsupported.
    public init(parsing url: URL) async throws {
        let fileType = AudioFileType(url: url)

        if fileType == .wav {
            self.init(url: url, fileType: fileType)
            try loadWave()
        } else {
            let audioFile = try AVAudioFile(forReading: url)
            self.init(
                url: url,
                fileType: fileType,
                audioFormat: AudioFormatProperties(audioFile: audioFile)
            )
            try await load()
        }

        if let bitRate = tagProperties.audioProperties?.bitRate {
            audioFormat?.update(bitRate: bitRate)
        }

        await updateDefaultImage()
    }

    private mutating func loadWave() throws {
        let waveFile = WaveFileC(path: url.path)

        guard waveFile.load() else {
            throw NSError(description: "Failed to load wave file at \(url.path)")
        }

        if let audioProperties = waveFile.audioPropertiesC {
            let format = AudioFormatProperties(cObject: audioProperties)
            audioFormat = format
            tagProperties.audioProperties = format
        }

        if let xml = waveFile.iXML {
            // validate and respace xml if it's valid
            iXMLMetadata =
                (try? AEXMLDocument(xml: xml).xml)
                    ?? xml //  otherwise just load the string as is
        }

        bextDescription = waveFile.bextDescription?.validated()

        if let audioMarkers = waveFile.markers as? [AudioMarker], audioMarkers.isNotEmpty {
            markerCollection = AudioMarkerDescriptionCollection(audioMarkers: audioMarkers)
        }

        // INFO
        if let dict = waveFile.infoDictionary as? [String: String] {
            for item in dict {
                guard let key = InfoFrameKey(value: item.key) else {
                    // Log.error("Unhandled INFO frame", item)
                    continue
                }

                tagProperties.data.set(infoFrame: key, value: item.value)
            }
        }

        // ID3
        if let dict = waveFile.id3Dictionary as? [String: String] {
            for item in dict {
                guard let key = ID3FrameKey(value: item.key) else {
                    tagProperties.data.set(taglibKey: item.key, value: item.value)
                    continue
                }

                switch key {
                case .picture:
                    continue
                case .userDefined:
                    // Log.error("User Defined", item.value)
                    break
                default:
                    tagProperties.data.set(id3Frame: key, value: item.value)
                }
            }
        }

        imageDescription.pictureRef = waveFile.tagPicture?.pictureRef
    }

    private mutating func load() async throws {
        // Not all formats are supported by TagLib (e.g., .caf),
        // so tag loading is best-effort.
        if let value = try? TagProperties(url: url) {
            tagProperties = value
        }

        if let value = try? await AudioMarkerDescriptionCollection(url: url) {
            markerCollection = value
        }

        imageDescription.pictureRef = try? TagPictureRef.parsing(url: url)
    }

    private mutating func updateDefaultImage() async {
        if imageDescription.cgImage == nil {
            imageDescription.cgImage = url.bestImageRepresentation?.cgImage
            imageDescription.description = url.path
        }

        await imageDescription.createThumbnail()
    }
}

extension MetaAudioFileDescription {
    /// Writes all current metadata back to the file.
    ///
    /// For WAV files, tags (BEXT, iXML, INFO, ID3) are always written via TagLib.
    /// Markers and artwork are conditionally written based on dirty flags.
    /// For other formats, tags are saved via TagLib and artwork is written separately if requested.
    /// Finder tags and modification date are updated after saving.
    ///
    /// - Parameter imageNeedsSave: If `true`, embedded artwork will also be written.
    public mutating func save(imageNeedsSave: Bool = false) throws {
        // Log.debug("Saving", url)

        if fileType == .wav {
            try saveWave(imageNeedsSave: imageNeedsSave)

        } else {
            try saveOther(imageNeedsSave: imageNeedsSave)
        }

        let finderTags = urlProperties.finderTags
        try url.set(finderTags: finderTags)
        try url.updateModificationDate()

        urlProperties = URLProperties(url: url)
    }

    private mutating func saveOther(imageNeedsSave: Bool = false) throws {
        try tagProperties.save(to: url)

        if imageNeedsSave, let pictureRef = imageDescription.pictureRef {
            try save(pictureRef: pictureRef)
        }
    }

    /// Writes embedded artwork to the file via TagLib.
    /// - Parameter pictureRef: The image data to embed.
    public func save(pictureRef: TagPictureRef) throws {
        guard TagPicture.write(pictureRef, path: url.path) else {
            throw NSError(description: "Failed to update image")
        }
    }

    /// Writes WAV metadata via TagLib (BEXT, iXML, ID3, INFO, artwork) and markers via AudioToolbox.
    /// Dirty flags control which chunks are actually written.
    private mutating func saveWave(imageNeedsSave: Bool = false) throws {
        let waveFile = WaveFileC(path: url.path)

        // extra chunks
        waveFile.bextDescription = bextDescription
        waveFile.iXML = iXMLMetadata
        waveFile.markers = audioMarkers

        // dirty flags
        waveFile.markersNeedsSave = !audioMarkers.isEmpty
        waveFile.imageNeedsSave = imageNeedsSave

        // image
        if imageNeedsSave, let pictureRef = imageDescription.pictureRef {
            waveFile.tagPicture = TagPicture(picture: pictureRef)
        }

        // metadata
        for item in tagProperties.tags {
            if item.key.id3Frame == .userDefined {
                waveFile.id3Dictionary[item.key.taglibKey] = item.value
            } else {
                waveFile[id3: item.key.id3Frame] = item.value
            }

            if let infoFrame = item.key.infoFrame {
                waveFile[info: infoFrame] = item.value
            }
        }

        for item in tagProperties.customTags {
            let uppercaseKey = item.key.uppercased()

            waveFile.id3Dictionary[uppercaseKey] = item.value

            if let infoFrame = InfoFrameKey(taglibKey: uppercaseKey) {
                waveFile[info: infoFrame] = item.value
            }
        }

        // Log.debug("id3Dictionary", waveFile.id3Dictionary)
        // Log.debug("infoDictionary", waveFile.infoDictionary)

        guard waveFile.save() else {
            throw NSError(description: "Failed to save \(url.path)")
        }
    }
}

extension MetaAudioFileDescription {
    /// Converts the ``markerCollection`` to an array of `AudioMarker` bridge objects for WAV file writing.
    public var audioMarkers: [AudioMarker] {
        var waveMarkers = [AudioMarker]()

        for i in 0 ..< markerCollection.markerDescriptions.count {
            let desc = markerCollection.markerDescriptions[i]

            waveMarkers.append(
                AudioMarker(
                    name: desc.name ?? "Marker",
                    time: desc.startTime,
                    sampleRate: audioFormat?.sampleRate ?? 0,
                    markerID: Int32(i)
                )
            )
        }

        return waveMarkers
    }
}
