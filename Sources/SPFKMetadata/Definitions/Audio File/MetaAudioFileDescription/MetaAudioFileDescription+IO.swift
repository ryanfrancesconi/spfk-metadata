// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AEXML
import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKFileSystem
import SPFKMatroska
import SPFKMetadataBase
import SPFKMetadataC
import SPFKUtils

extension MetaAudioFileDescription {
    /// Reads all metadata from the file. Throws when no reader can open it.
    public init(parsing url: URL) async throws {
        let fileType = AudioFileType(url: url)
        let route = try await ParseRoute(url: url, fileType: fileType)

        self.init(url: url, fileType: fileType, audioFormat: route.audioFormat)

        switch route {
        case .wave:
            try loadWave()

        case .audioFile:
            try await load()

            if fileType == .flac {
                loadFLAC()
            }

        case let .tagStore(error):
            try await load()

            guard let properties = tagProperties.audioProperties else { throw error }
            audioFormat = properties

        case .asset:
            try await load()
        }

        // A malformed container (a WAV with a wrong RIFF size) can open and still report 0 frames.
        isAVPlayable = route.frameCount > 0

        if isAVPlayable == false {
            isDecodable = (try? MatroskaFile(url: url))?.audioTrack?.isDecodable == true
        }

        if let bitRate = tagProperties.audioProperties?.bitRate {
            audioFormat?.update(bitRate: bitRate)
        }

        // Each read gates on its own formats; a WAV reaches neither.
        await loadVideoTrack()

        await updateImageThumbnail()
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
            iXMLMetadata = (try? AEXMLDocument(xml: xml).xml) ?? xml
        }

        bextDescription = waveFile.bextDescription?.validated()

        if let audioMarkers = waveFile.markers as? [AudioMarker], audioMarkers.isNotEmpty {
            markerCollection = AudioMarkerDescriptionCollection(audioMarkers: audioMarkers)
        }

        if let dict = waveFile.infoDictionary as? [String: String] {
            for item in dict {
                guard let key = InfoFrameKey(value: item.key) else { continue }

                tagProperties.data.set(infoFrame: key, value: item.value)
            }
        }

        if let dict = waveFile.id3Dictionary as? [String: String] {
            for item in dict {
                guard let key = ID3FrameKey(value: item.key) else {
                    tagProperties.data.set(taglibKey: item.key, value: item.value)
                    continue
                }

                switch key {
                case .picture:
                    continue
                case .rating:
                    continue // raw POPM; the rating arrives as the RATING key WaveFileC injects
                case .userDefined:
                    break
                default:
                    tagProperties.data.set(id3Frame: key, value: item.value)
                }
            }
        }

        imageDescription.pictureRef = waveFile.tagPicture?.pictureRef
    }

    /// Adds FLAC's iXML and BEXT APPLICATION blocks to what `load()` read. BEXT falls back to
    /// iXML's `<BEXT>` element, where Sequoia writes it.
    private mutating func loadFLAC() {
        let flacFile = FlacFileC(path: url.path)
        guard flacFile.load() else { return }

        if let props = flacFile.audioPropertiesC, props.bitsPerSample > 0 {
            audioFormat?.update(bitsPerChannel: Int(props.bitsPerSample))
        }

        if let xml = flacFile.iXML {
            iXMLMetadata = (try? AEXMLDocument(xml: xml).xml) ?? xml
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

    private mutating func load() async throws {
        // Best-effort: TagLib does not read every format (.caf).
        if let value = try? TagProperties(url: url) {
            tagProperties = value
        }

        if let value = try? await AudioMarkerDescriptionCollection(url: url) {
            markerCollection = value
        }

        imageDescription.pictureRef = try? TagPictureRef.parsing(url: url)
    }

    /// No embedded artwork means no thumbnail. The Finder icon is per-machine, not file content,
    /// so display supplies it: `NSWorkspace.FinderIcon.fileType(for:)`.
    private mutating func updateImageThumbnail() async {
        if imageDescription.cgImage == nil {
            imageDescription.description = url.path
        }

        await imageDescription.createThumbnail()
    }
}

extension MetaAudioFileDescription {
    /// Writes what `dirtyFlags` names, then the Finder tags and modification date. `.xmp` is
    /// written elsewhere.
    public mutating func save(dirtyFlags: Set<MetadataDirtyFlag> = [.metadata]) throws {
        // First, so a locked file fails with one error rather than a partial save; TagLib
        // reports the lock only as `false`.
        try url.requireWritable()

        let imageNeedsSave = dirtyFlags.contains(.image)
        let markersNeedsSave = dirtyFlags.contains(.markers)

        // A container rewrite costs the whole file (20-30 s at 4 GB); a Finder tag change shouldn't pay it.
        if dirtyFlags.contains(.metadata) || imageNeedsSave || markersNeedsSave {
            if fileType == .wav {
                try saveWave(imageNeedsSave: imageNeedsSave, markersNeedsSave: markersNeedsSave)

            } else if fileType == .flac {
                try saveFLAC()
                try saveOther(imageNeedsSave: imageNeedsSave, markersNeedsSave: markersNeedsSave)

            } else {
                try saveOther(imageNeedsSave: imageNeedsSave, markersNeedsSave: markersNeedsSave)
            }
        }

        #if os(macOS)
            let finderTags = urlProperties.finderTags
            try url.set(finderTags: finderTags)
            try url.updateModificationDate()

            // Rebuilt, or a stale date reads as an external change on the next scan.
            urlProperties = URLProperties(url: url)
        #endif
    }

    /// Writes FLAC's iXML and BEXT APPLICATION blocks. Must run before `saveOther()`, whose TagLib
    /// save keeps APPLICATION blocks already on disk.
    private func saveFLAC() throws {
        let flacFile = FlacFileC(path: url.path)
        guard flacFile.load() else {
            throw NSError(description: "Failed to open \(url.path) for FLAC iXML/BEXT writing")
        }

        flacFile.bextDescription = bextDescription
        flacFile.iXML = iXMLMetadata

        guard flacFile.save() else {
            throw NSError(description: "Failed to write iXML/BEXT to \(url.path)")
        }
    }

    private mutating func saveOther(imageNeedsSave: Bool = false, markersNeedsSave: Bool = false) throws {
        // Keeps the existing artwork; an artwork change is applied below.
        try tagProperties.save(to: url)

        if imageNeedsSave {
            if let pictureRef = imageDescription.pictureRef {
                try save(pictureRef: pictureRef)
            } else {
                try removePicture()
            }
        }

        if markersNeedsSave {
            try saveMarkers()
        }
    }

    /// Embeds artwork through TagLib.
    public func save(pictureRef: TagPictureRef) throws {
        guard TagPicture.write(pictureRef, path: url.path) else {
            throw NSError(description: "Failed to update image")
        }
    }

    /// Removes embedded artwork from the file via TagLib and clears it from memory.
    public mutating func removePicture() throws {
        guard TagPicture.write(nil, path: url.path) else {
            throw NSError(description: "Failed to remove image from \(url.path)")
        }
        imageDescription.cgImage = nil
    }

    /// Tags and chunks are always written; markers and artwork only when flagged.
    private mutating func saveWave(imageNeedsSave: Bool = false, markersNeedsSave: Bool = false) throws {
        let waveFile = WaveFileC(path: url.path)

        waveFile.bextDescription = bextDescription
        waveFile.iXML = iXMLMetadata
        waveFile.markers = audioMarkers

        waveFile.markersNeedsSave = markersNeedsSave
        waveFile.imageNeedsSave = imageNeedsSave

        // Passed even when not flagged, or a tags-only save drops the artwork.
        if let pictureRef = imageDescription.pictureRef {
            waveFile.tagPicture = TagPicture(picture: pictureRef)
        }

        for item in tagProperties.tags {
            if item.key.id3Frame == .userDefined || item.key.id3Frame == .rating {
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

        guard waveFile.save() else {
            throw NSError(description: "Failed to save \(url.path)")
        }
    }

    /// Keep the format lists in step with `AudioMarkerDescriptionCollection.init(url:fileType:)`,
    /// or markers are written that can't be read back. Runs last, so throwing costs only the markers.
    private func saveMarkers() throws {
        let path = url.path
        let success: Bool

        switch fileType {
        case .mp3:
            success = MPEGChapterUtil.write(markerCollection.colorEncodedChapterMarkers, to: path)

        case .m4a, .mp4, .aac, .m4b, .mov, .m4v:
            success = MP4ChapterUtil.write(markerCollection.fileEncodedChapterMarkers, to: path)

        case .flac, .ogg, .opus:
            success = XiphChapterUtil.write(markerCollection.colorEncodedChapterMarkers, to: path)

        case .aiff, .aifc:
            success = AudioMarkerUtil.write(audioMarkers, to: url)

        default:
            // Returning here would clear the dirty flag and lose the markers.
            throw NSError(
                file: #file, function: #function,
                description: "Markers are not supported for \(fileType?.rawValue ?? "unknown") files"
            )
        }

        guard success else {
            throw NSError(description: "Failed to save markers to \(url.path)")
        }
    }
}

extension MetaAudioFileDescription {
    /// For WAV and AIFF. A region's end time and color ride in a JSON suffix on the name, since
    /// cue points have neither.
    public var audioMarkers: [AudioMarker] {
        markerCollection.markerDescriptions.enumerated().map { i, desc in
            desc.audioMarker(markerID: i, fileType: fileType, fileSampleRate: audioFormat?.sampleRate)
        }
    }
}
