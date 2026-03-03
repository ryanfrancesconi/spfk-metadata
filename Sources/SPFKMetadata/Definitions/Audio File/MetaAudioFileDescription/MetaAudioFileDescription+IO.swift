// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AEXML
import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKMetadataC
import SPFKUtils

extension MetaAudioFileDescription {
    public init(parsing url: URL) async throws {
        let audioFile = try AVAudioFile(forReading: url)
        audioFormat = AudioFormatProperties(audioFile: audioFile)

        self.url = url
        urlProperties = URLProperties(url: url)
        fileType = AudioFileType(url: url)

        if fileType == .wav {
            try loadWave()

        } else {
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
            tagProperties.audioProperties = AudioFormatProperties(cObject: audioProperties)
        }

        if let xml = waveFile.iXML {
            // validate and respace xml if it's valid
            iXMLMetadata = (try? AEXMLDocument(xml: xml).xml)
                ?? xml //  otherwise just load the string as is
        }

        bextDescription = waveFile.bextDescription?.validated()

        if let audioMarkers = waveFile.markers as? [AudioMarker] {
            markerCollection = AudioMarkerDescriptionCollection(audioMarkers: audioMarkers)
        }

        // INFO
        if let dict = waveFile.infoDictionary as? [String: String] {
            for item in dict {
                guard let key = InfoFrameKey(value: item.key) else {
                    Log.error("Unhandled INFO frame", item)
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
                    Log.error("User Defined", item.value)
                default:
                    tagProperties.data.set(id3Frame: key, value: item.value)
                }
            }
        }

        imageDescription.pictureRef = waveFile.tagPicture?.pictureRef
    }

    private mutating func load() async throws {
        tagProperties = try TagProperties(url: url)

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
    public mutating func save(imageNeedsSave: Bool = false) throws {
        // Log.debug("Saving", url)

        if fileType == .wav {
            try saveWave()

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

    public func save(pictureRef: TagPictureRef) throws {
        guard TagPicture.write(pictureRef, path: url.path) else {
            throw NSError(description: "Failed to update image")
        }
    }

    /// In the case of Wave, all chunks are written out if present (so all properties must be updated)
    /// This is due to the BEXT chunk handler in libsndfile only supporting writing a new file
    /// rather than updating a header. This is a point to improve in the future if the bext write
    /// is integrated into the taglib save().
    private mutating func saveWave() throws {
        let waveFile = WaveFileC(path: url.path)

        // extra chunks
        waveFile.bextDescription = bextDescription
        waveFile.iXML = iXMLMetadata
        waveFile.markers = audioMarkers

        // image
        if let pictureRef = imageDescription.pictureRef {
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
