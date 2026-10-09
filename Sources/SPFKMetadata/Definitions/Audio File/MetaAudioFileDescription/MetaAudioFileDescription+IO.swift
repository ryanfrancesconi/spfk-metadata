// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKFileSystem
import SPFKMatroska
import SPFKMetadataBase
internal import SPFKMetadataC
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

        readEmbeddedMetadata(from: waveFile)

        if let audioMarkers = waveFile.markers as? [AudioMarker], audioMarkers.isNotEmpty {
            markerCollection = AudioMarkerDescriptionCollection(audioMarkers: audioMarkers)
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

        readEmbeddedMetadata(from: flacFile)
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
    /// written elsewhere; `storedXMPPacket` replaces or removes the packet a WAV or MP3 stores,
    /// in the same TagLib save.
    ///
    /// Throws ``MetadataError/writeFailed(_:_:)`` for a component that could not be written and
    /// ``UnstorableMetadataError`` for flags the container has no writer for, each after writing
    /// everything else.
    public mutating func save(
        dirtyFlags: Set<MetadataDirtyFlag> = [.metadata],
        storedXMPPacket: StoredXMPPacketWrite = .keep
    ) throws {
        // First, so a locked file fails with one error rather than a partial save; TagLib
        // reports the lock only as `false`.
        try url.requireWritable()

        if storedXMPPacket != .keep, !(fileType.map(StoredXMPPacketWrite.fileTypes.contains) ?? false) {
            throw NSError(description: "A .\(url.pathExtension) file stores no XMP packet of its own")
        }

        let unstorable = unstorableFlags(in: dirtyFlags)
        let writable = dirtyFlags.subtracting(unstorable)

        // Nothing else to write, so the file is left untouched, modification date included.
        if unstorable.isNotEmpty, writable.isEmpty {
            throw UnstorableMetadataError(fileType: fileType, flags: unstorable)
        }

        let imageNeedsSave = writable.contains(.image)
        let markersNeedsSave = writable.contains(.markers)

        // A container save can rewrite the whole file; a Finder tag change shouldn't pay it.
        let containerNeedsSave = writable.contains(.metadata) || imageNeedsSave || markersNeedsSave

        if !containerNeedsSave {
            try storedXMPPacket.write(to: url)
        } else {
            if fileType == .wav {
                try saveWave(
                    metadataNeedsSave: writable.contains(.metadata), imageNeedsSave: imageNeedsSave,
                    markersNeedsSave: markersNeedsSave, storedXMPPacket: storedXMPPacket
                )
            } else {
                try saveSession(
                    metadataNeedsSave: writable.contains(.metadata), imageNeedsSave: imageNeedsSave,
                    markersNeedsSave: markersNeedsSave, storedXMPPacket: storedXMPPacket
                )
            }
        }

        #if os(macOS)
            let finderTags = urlProperties.finderTags
            try url.set(finderTags: finderTags)
            try url.updateModificationDate()

            // Rebuilt, or a stale date reads as an external change on the next scan.
            urlProperties = URLProperties(url: url)
        #endif

        if unstorable.isNotEmpty {
            throw UnstorableMetadataError(fileType: fileType, flags: unstorable)
        }
    }

    /// Every component written into one TagLib open and saved once. A component that fails throws
    /// after everything else is saved. A FLAC's BEXT and iXML are written only when they differ
    /// from the file's.
    private mutating func saveSession(
        metadataNeedsSave: Bool, imageNeedsSave: Bool, markersNeedsSave: Bool, storedXMPPacket: StoredXMPPacketWrite
    ) throws {
        guard let session = MetadataSaveSession(path: url.path) else {
            throw MetadataError.writeFailed(.tags, url)
        }

        var failed: Set<MetadataError.Component> = []

        // Keeps the existing artwork; an artwork change is written below.
        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = tagProperties.tagLibPropertyMap
        storedXMPPacket.apply { tagFile.xmpNeedsSave = true; tagFile.xmpPacket = $0 }

        if !tagFile.write(toFileRef: session.fileRef) {
            failed.insert(.rating)
        }

        if fileType == .flac, metadataNeedsSave {
            let stored = FlacFileC(path: url.path)
            let flacFile = FlacFileC(path: url.path)
            flacFile.bextDescription = bextDescription
            flacFile.iXML = iXMLMetadata

            if stored.read(fromFile: session.file) {
                flacFile.bextNeedsSave = bextDiffers(from: stored.parsedBEXT)
                flacFile.iXMLNeedsSave = !IXMLMetadata.isUnedited(iXMLMetadata, stored: stored.iXML)
            }

            if !flacFile.write(toFile: session.file) {
                failed.insert(.bext)
            }
        }

        if imageNeedsSave, !TagPicture.write(pictureRefToWrite, toFileRef: session.fileRef) {
            failed.insert(.artwork)
        }

        var unstorableMarkers = false

        if markersNeedsSave {
            switch saveMarkers(into: session) {
            case true?: break
            case false?: failed.insert(.markers)
            case nil: unstorableMarkers = true
            }
        }

        guard session.save() else {
            throw MetadataError.writeFailed(.tags, url)
        }

        if imageNeedsSave, pictureRefToWrite == nil {
            imageDescription.cgImage = nil
        }

        if let component = [MetadataError.Component.artwork, .markers, .bext, .rating].first(where: failed.contains) {
            throw MetadataError.writeFailed(component, url)
        }

        // `save(dirtyFlags:)` filters on `AudioFileType.markerWriteTypes`, derived from the same
        // storage, so this is unreachable. Returning would clear the dirty flag and lose the markers.
        if unstorableMarkers {
            throw UnstorableMetadataError(fileType: fileType, flags: [.markers])
        }
    }

    /// `imageDescription.pictureRef`, minus the file's own path: a parse without artwork leaves it
    /// in `description` for display, and it must not be written into the file.
    private var pictureRefToWrite: TagPictureRef? {
        guard let pictureRef = imageDescription.pictureRef else { return nil }

        if pictureRef.pictureDescription == url.path {
            pictureRef.pictureDescription = ""
        }

        return pictureRef
    }

    /// Removes embedded artwork from the file via TagLib and clears it from memory.
    public mutating func removePicture() throws {
        guard TagPicture.write(nil, path: url.path) else {
            throw NSError(description: "Failed to remove image from \(url.path)")
        }
        imageDescription.cgImage = nil
    }

    /// Markers and artwork are written only when flagged; the tags, BEXT and iXML only when
    /// `.metadata` is and they differ from the file's. A failed artwork, marker or rating write
    /// throws after the rest is saved.
    private mutating func saveWave(
        metadataNeedsSave: Bool, imageNeedsSave: Bool, markersNeedsSave: Bool, storedXMPPacket: StoredXMPPacketWrite
    ) throws {
        let waveFile = WaveFileC(path: url.path)
        storedXMPPacket.apply { waveFile.xmpNeedsSave = true; waveFile.xmpPacket = $0 }

        waveFile.bextDescription = bextDescription
        waveFile.iXML = iXMLMetadata
        waveFile.markers = audioMarkers

        waveFile.markersNeedsSave = markersNeedsSave
        waveFile.imageNeedsSave = imageNeedsSave

        if imageNeedsSave, let pictureRef = pictureRefToWrite {
            waveFile.tagPicture = TagPicture(picture: pictureRef)
        }

        if metadataNeedsSave {
            setMetadataChanges(on: waveFile)
        } else {
            waveFile.tagsNeedsSave = false
            waveFile.bextNeedsSave = false
            waveFile.iXMLNeedsSave = false
        }

        guard waveFile.save() else {
            throw MetadataError.writeFailed(waveFile.failedComponent, url)
        }
    }

    /// The tags, BEXT and iXML that differ from the file's; all of them when it can't be read.
    private func setMetadataChanges(on waveFile: WaveFileC) {
        let stored = WaveFileC(path: url.path)

        guard stored.loadTags() else {
            waveFile.setTags(tagProperties)
            return
        }

        waveFile.setTagChanges(tagProperties, storedIn: stored)
        waveFile.bextNeedsSave = bextDiffers(from: stored.bextDescription?.validated())
        waveFile.iXMLNeedsSave = !IXMLMetadata.isUnedited(iXMLMetadata, stored: stored.iXML)
    }

    /// The markers' part of a save, written into `session`: false when they fail, nil when the
    /// container has no storage a save writes. WAV's go through `saveWave()`.
    private func saveMarkers(into session: MetadataSaveSession) -> Bool? {
        switch fileType?.markerStorage {
        case .id3Chapters:
            MPEGChapterUtil.write(markerCollection.colorEncodedChapterMarkers, toFile: session.file)
        case .mp4Chapters:
            MP4ChapterUtil.write(markerCollection.fileEncodedChapterMarkers, toFile: session.file)
        case .xiphChapters:
            XiphChapterUtil.write(markerCollection.colorEncodedChapterMarkers, toFile: session.file)
        case .aiffMarks:
            setAIFFMarkers(in: session)
        case .riffCues, .coreAudio, nil:
            nil
        }
    }
}

extension MetaAudioFileDescription {
    /// Whether `stored` holds other BEXT fields than the description. The sample rate is the host
    /// file's, not a field, and a description decoded from a library may lack it.
    private func bextDiffers(from stored: BEXTDescription?) -> Bool {
        var stored = stored
        stored?.sampleRate = bextDescription?.sampleRate
        return stored != bextDescription
    }

    /// Positions convert at the sample rate Core Audio reads, as its own marker write did.
    private func setAIFFMarkers(in session: MetadataSaveSession) -> Bool {
        guard let sampleRate = audioFormat?.sampleRate, sampleRate > 0 else { return false }
        session.setAIFFMarkers(audioMarkers, sampleRate: sampleRate)
        return true
    }

    /// For WAV and AIFF. A region's end time and color ride in a JSON suffix on the name, since
    /// cue points have neither.
    var audioMarkers: [AudioMarker] {
        markerCollection.markerDescriptions.enumerated().map { i, desc in
            desc.audioMarker(markerID: i, fileType: fileType, fileSampleRate: audioFormat?.sampleRate)
        }
    }
}
