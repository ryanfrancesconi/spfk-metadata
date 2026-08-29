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
        var avFrameCount: AVAudioFramePosition = 0

        if fileType == .wav {
            self.init(url: url, fileType: fileType)
            try loadWave()
            avFrameCount = (try? AVAudioFile(forReading: url))?.length ?? 0

        } else {
            switch Result(catching: { try AVAudioFile(forReading: url) }) {
            case let .success(audioFile):
                avFrameCount = audioFile.length

                self.init(
                    url: url,
                    fileType: fileType,
                    audioFormat: AudioFormatProperties(audioFile: audioFile)
                )
                try await load()

                if fileType == .flac {
                    loadFLAC()
                }

            case let .failure(error):
                // A container AVFoundation cannot open at all -- Matroska in practice, the one
                // video container it refuses among the set this app otherwise holds. TagLib reads
                // its tags and its stream properties perfectly well, so the file becomes a real,
                // taggable row rather than an import error; only playback is unavailable, which is
                // what `isAVPlayable` below already says and the waveform path already handles.
                //
                // Deliberately not gated on Matroska by name. The question a format can answer for
                // itself is "do I claim metadata support", and a hardcoded list here would be the
                // fourth copy of a capability that already has an owner.
                guard fileType?.supportsMetadata == true else { throw error }

                self.init(url: url, fileType: fileType)
                try await load()

                // TagLib has to have produced real stream properties, or there is nothing behind
                // this row at all and AVFoundation's original failure is the honest answer. This is
                // what keeps a genuinely corrupt file an import error instead of an empty row.
                guard let properties = tagProperties.audioProperties else { throw error }
                audioFormat = properties
            }
        }

        // A file is considered not AV-playable when AVAudioFile opens it successfully
        // but reports 0 frames. This happens with malformed containers (e.g. WAV files
        // whose RIFF chunk size header is wrong) where AVFoundation stops reading at the
        // declared boundary and never finds the audio data.
        isAVPlayable = avFrameCount > 0

        if isAVPlayable == false {
            isDecodable = (try? MatroskaFile(url: url))?.audioTrack?.isDecodable == true
        }

        if let bitRate = tagProperties.audioProperties?.bitRate {
            audioFormat?.update(bitRate: bitRate)
        }

        // Purely additive, parallel read path — populates videoTrack/quickTimeUserData and the
        // audio track listing via AVFoundation. Each half carries its own format gate; a WAV
        // reaches neither.
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
                case .rating:
                    continue // handled via WaveFileC id3Dictionary injection
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

    /// Reads iXML and BEXT APPLICATION blocks from a FLAC file, supplementing the
    /// generic Xiph-tag load already performed by `load()`.
    ///
    /// BEXT priority: binary APPLICATION block (canonical) → iXML `<BEXT>` element (fallback).
    /// The fallback covers Sequoia-style FLAC files that embed BEXT info inside iXML only.
    private mutating func loadFLAC() {
        let flacFile = FlacFileC(path: url.path)
        guard flacFile.load() else { return }

        if let props = flacFile.audioPropertiesC, props.bitsPerSample > 0 {
            audioFormat?.update(bitsPerChannel: Int(props.bitsPerSample))
        }

        if let xml = flacFile.iXML {
            iXMLMetadata =
                (try? AEXMLDocument(xml: xml).xml)
                    ?? xml
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

    /// A file with no embedded artwork keeps a nil image and gets no thumbnail. Substituting the
    /// file's Finder icon here would store a per-machine, per-installed-app image as if it were
    /// artwork, and leave a row's icon changing whenever a reparse happened to touch it. Display
    /// resolves that fallback instead -- see `NSWorkspace.FinderIcon.fileType(for:)`.
    private mutating func updateImageThumbnail() async {
        if imageDescription.cgImage == nil {
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
    /// For other formats, tags are saved via TagLib, artwork and markers are written separately if requested.
    /// Finder tags and modification date are updated after saving.
    ///
    /// - Parameter dirtyFlags: The set of metadata aspects that need saving.
    ///   Defaults to `[.metadata]` (tags only). Include `.image` for artwork,
    ///   `.markers` for markers. The `.xmp` flag is handled externally.
    public mutating func save(dirtyFlags: Set<MetadataDirtyFlag> = [.metadata]) throws {
        // Log.debug("Saving", url)

        // A pending unlock is applied *before* the guard, not gated by it: clearing the flag is
        // part of this save rather than a precondition of it, and checking first would make the
        // save refuse the very edit that would let it proceed.
        #if os(macOS)
            if dirtyFlags.contains(.lock), urlProperties.lockState == .writable {
                try url.unlock()
            }
        #endif

        // The `uchg` flag refuses the tag write, the Finder-tag write and the modification-date
        // bump alike, and TagLib reports its share of that as a bare `false` with no reason
        // attached -- so one error here, rather than a partial save that leaves tags on disk and
        // Finder tags not.
        try url.requireWritable()

        let imageNeedsSave = dirtyFlags.contains(.image)
        let markersNeedsSave = dirtyFlags.contains(.markers)

        // Gated, because the tail below runs on every save and these do not. Rewriting the
        // container costs the whole file -- 20-30 s on a 4 GB source, the same rewrite the save
        // progress reports -- and a Finder tag or a lock change has no business paying it.
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

            // Last, and after the modification-date bump: everything above fails on a locked file.
            if dirtyFlags.contains(.lock), urlProperties.lockState == .locked {
                try url.lock()
            }

            // Rebuilt rather than patched, which is what keeps the recorded dates equal to the
            // ones this save produced. An element left claiming a date the file no longer has is
            // reported as an external change by the next observer scan.
            urlProperties = URLProperties(url: url)
        #endif
    }

    /// Writes iXML and BEXT APPLICATION blocks to the FLAC file.
    ///
    /// Must be called before `saveOther()` so the APPLICATION blocks are on disk when
    /// TagLib reopens the file to write Xiph comment tags. TagLib's `strip()` for FLAC
    /// removes only ID3 and Xiph tags, not APPLICATION blocks, so the blocks survive.
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
        // tagProperties.save() preserves any existing embedded artwork at the C++ level —
        // it captures the PICTURE block before stripping and restores it after. Callers that
        // explicitly change artwork (imageNeedsSave) follow up below to overwrite or clear it.
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

    /// Writes embedded artwork to the file via TagLib.
    /// - Parameter pictureRef: The image data to embed.
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

    /// Writes WAV metadata via TagLib (BEXT, iXML, ID3, INFO, artwork) and markers via AudioToolbox.
    /// Dirty flags control which chunks are actually written.
    private mutating func saveWave(imageNeedsSave: Bool = false, markersNeedsSave: Bool = false) throws {
        let waveFile = WaveFileC(path: url.path)

        // extra chunks
        waveFile.bextDescription = bextDescription
        waveFile.iXML = iXMLMetadata
        waveFile.markers = audioMarkers

        // dirty flags
        waveFile.markersNeedsSave = markersNeedsSave
        waveFile.imageNeedsSave = imageNeedsSave

        // image
        // Always pass the picture to WaveFileC if one exists in memory, so that
        // a metadata-only save doesn't discard existing embedded artwork. The
        // imageNeedsSave flag still controls whether WaveFileC actually writes it.
        if let pictureRef = imageDescription.pictureRef {
            waveFile.tagPicture = TagPicture(picture: pictureRef)
        }

        // metadata
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

        // Log.debug("id3Dictionary", waveFile.id3Dictionary)
        // Log.debug("infoDictionary", waveFile.infoDictionary)

        guard waveFile.save() else {
            throw NSError(description: "Failed to save \(url.path)")
        }
    }

    /// Writes markers to non-WAV files via format-specific utilities.
    ///
    /// Dispatches to `MP4ChapterUtil`, `MPEGChapterUtil`, `XiphChapterUtil`, or
    /// `AudioMarkerUtil` depending on `fileType`. Keep the type lists here in step with
    /// `AudioMarkerDescriptionCollection.init(url:fileType:)` — markers written by one and not
    /// readable by the other look to the user exactly like data loss.
    ///
    /// Only reached when the `.markers` dirty flag is set, and only after tags and artwork are
    /// already on disk — so throwing for a format that genuinely can't hold markers reports the
    /// real problem without costing the caller the rest of the save.
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
            // Previously logged and returned, which reported a successful save and cleared the
            // dirty flag while discarding every marker the user had set.
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
    /// Converts the ``markerCollection`` to an array of `AudioMarker` bridge objects for WAV/AIFF writing.
    ///
    /// Region markers (.region) encode their endTime and color as a JSON suffix in the name
    /// so the data survives the RIFF cue-point format, which has no native endTime or color fields.
    public var audioMarkers: [AudioMarker] {
        var waveMarkers = [AudioMarker]()

        for i in 0 ..< markerCollection.markerDescriptions.count {
            let desc = markerCollection.markerDescriptions[i]

            waveMarkers.append(
                AudioMarker(
                    name: desc.fileEncodedName,
                    time: desc.startTime,
                    sampleRate: audioFormat?.sampleRate ?? 0,
                    markerID: Int32(i)
                )
            )
        }

        return waveMarkers
    }
}
