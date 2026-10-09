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
    /// Reads all metadata from the file. Throws when no reader can open it; a component whose
    /// reader alone fails is recorded in ``readStatus``.
    public init(parsing url: URL) async throws {
        try await self.init(parsing: url, reads: ParseReads())
    }

    init(parsing url: URL, reads: ParseReads) async throws {
        let fileType = AudioFileType(url: url)
        let route = try await ParseRoute(url: url, fileType: fileType)

        self.init(url: url, fileType: fileType, audioFormat: route.audioFormat)

        var frameCount = route.frameCount

        switch route {
        case .wave:
            frameCount = try loadWave()

        case .audioFile:
            await load(reads)

            if fileType == .flac {
                loadFLAC(reads)
            }

        case let .tagStore(error):
            await load(reads)

            guard let properties = tagProperties.audioProperties else { throw error }
            audioFormat = properties

        case .asset:
            await load(reads)
        }

        // A malformed container (a WAV with a wrong RIFF size) can open and still report 0 frames.
        isAVPlayable = (frameCount ?? 0) > 0

        if isAVPlayable == false {
            isDecodable = (try? MatroskaFile(url: url))?.audioTrack?.isDecodable == true
        }

        if let bitRate = tagProperties.audioProperties?.bitRate {
            audioFormat?.update(bitRate: bitRate)
        }

        // Each read gates on its own formats; a WAV reaches neither.
        await loadVideoTrack()

        // No thumbnail: its decode costs more than the rest of the parse with a large cover, so
        // whoever displays the artwork makes it (`ArtworkDescription.createThumbnail()`). Without
        // artwork, display supplies the Finder icon, which is per-machine rather than file content.
        if imageDescription.cgImage == nil {
            imageDescription.description = url.path
        }
    }

    /// The frames AVFoundation can play: the chunks' count, or `AVAudioFile`'s where they give none.
    private mutating func loadWave() throws -> AVAudioFramePosition {
        let waveFile = WaveFileC(path: url.path)

        guard waveFile.load() else {
            throw MetadataError.openFailed(url)
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

        guard waveFile.frameCount < 0 else { return waveFile.frameCount }
        return (try? AVAudioFile(forReading: url))?.length ?? 0
    }

    /// Adds FLAC's iXML and BEXT APPLICATION blocks to what `load()` read. BEXT falls back to
    /// iXML's `<BEXT>` element, where Sequoia writes it.
    private mutating func loadFLAC(_ reads: ParseReads) {
        let flacFile = FlacFileC(path: url.path)

        guard reads.flacChunks(flacFile) else {
            readStatus.failed.formUnion([.bext, .ixml])
            return
        }

        if let props = flacFile.audioPropertiesC, props.bitsPerSample > 0 {
            audioFormat?.update(bitsPerChannel: Int(props.bitsPerSample))
        }

        readEmbeddedMetadata(from: flacFile)
    }

    private mutating func load(_ reads: ParseReads) async {
        do {
            tagProperties = try reads.tags(url)
        } catch {
            // TagLib reads no tags from a container nothing can write them to (.caf).
            if canStoreTags { readStatus.failed.insert(.tags) }
        }

        do {
            markerCollection = try await reads.markers(url, fileType)
        } catch MetadataError.unsupportedFormat {
            // The container has nowhere to keep markers.
        } catch {
            readStatus.failed.insert(.markers)
        }

        imageDescription.pictureRef = try? TagPictureRef.parsing(url: url)
    }
}

extension MetaAudioFileDescription {
    /// Every component of `writable` written into one TagLib open and saved once, returning those
    /// that failed; throws when nothing could be saved. A FLAC's BEXT and iXML are written only
    /// when they differ from the file's. Tags the parse could not read are left as the file has them.
    mutating func saveSession(
        _ writable: Set<MetadataComponent>, storedXMPPacket: StoredXMPPacketWrite
    ) throws -> Set<MetadataComponent> {
        guard let session = MetadataSaveSession(path: url.path) else {
            throw MetadataError.saveFailed(url)
        }

        let imageNeedsSave = writable.contains(.artwork)

        var failed: Set<MetadataComponent> = []
        let tagsWereRead = readStatus.holdsFileValue(of: .tags)

        // Every container save writes the whole tag map. Keeps the existing artwork; an artwork
        // change is written below.
        if tagsWereRead {
            let tagFile = TagFile(path: url.path)
            tagFile.dictionary = tagProperties.tagLibPropertyMap
            storedXMPPacket.apply { tagFile.xmpNeedsSave = true; tagFile.xmpPacket = $0 }

            if !tagFile.write(toFileRef: session.fileRef) {
                failed.insert(.rating)
            }
        }

        if fileType == .flac, !writable.isDisjoint(with: [.bext, .ixml]) {
            let stored = FlacFileC(path: url.path)
            let flacFile = FlacFileC(path: url.path)
            flacFile.bextDescription = bextDescription
            flacFile.iXML = iXMLMetadata

            if stored.read(fromFile: session.file) {
                flacFile.bextNeedsSave = bextDiffers(from: stored.parsedBEXT)
                flacFile.iXMLNeedsSave = !IXMLMetadata.isUnedited(iXMLMetadata, stored: stored.iXML)
            }

            flacFile.bextNeedsSave = flacFile.bextNeedsSave && writable.contains(.bext)
            flacFile.iXMLNeedsSave = flacFile.iXMLNeedsSave && writable.contains(.ixml)

            if !flacFile.write(toFile: session.file) {
                if flacFile.bextNeedsSave { failed.insert(.bext) }
                if flacFile.iXMLNeedsSave { failed.insert(.ixml) }
            }
        }

        if imageNeedsSave, !TagPicture.write(pictureRefToWrite, toFileRef: session.fileRef) {
            failed.insert(.artwork)
        }

        // A nil result is unreachable: `save(dirtyFlags:)` filters on `markerWriteTypes`, derived
        // from the same storage. Counted as failed, so the dirty flag is kept.
        if writable.contains(.markers), saveMarkers(into: session) != true {
            failed.insert(.markers)
        }

        guard session.save() else {
            throw MetadataError.saveFailed(url)
        }

        // The packet rides the tag write, so it goes alone when that was skipped.
        if !tagsWereRead {
            do { try storedXMPPacket.write(to: url) } catch { failed.insert(.xmp) }
        }

        if imageNeedsSave, pictureRefToWrite == nil {
            imageDescription.cgImage = nil
        }

        return failed
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
            throw MetadataError.removeFailed(.artwork, url)
        }
        imageDescription.cgImage = nil
    }

    /// Markers and artwork are written only when in `writable`; the tags, BEXT and iXML only when
    /// they are and differ from the file's. Returns the components that failed; throws when nothing
    /// could be saved.
    mutating func saveWave(
        _ writable: Set<MetadataComponent>, storedXMPPacket: StoredXMPPacketWrite
    ) throws -> Set<MetadataComponent> {
        let imageNeedsSave = writable.contains(.artwork)
        let waveFile = WaveFileC(path: url.path)
        storedXMPPacket.apply { waveFile.xmpNeedsSave = true; waveFile.xmpPacket = $0 }

        waveFile.bextDescription = bextDescription
        waveFile.iXML = iXMLMetadata
        waveFile.markers = audioMarkers

        waveFile.markersNeedsSave = writable.contains(.markers)
        waveFile.imageNeedsSave = imageNeedsSave

        if imageNeedsSave, let pictureRef = pictureRefToWrite {
            waveFile.tagPicture = TagPicture(picture: pictureRef)
        }

        if !writable.isDisjoint(with: [.tags, .bext, .ixml]) {
            setMetadataChanges(on: waveFile)
        }

        if !writable.contains(.tags) {
            waveFile.tagsNeedsSave = false
            waveFile.ratingNeedsSave = false
        }

        waveFile.bextNeedsSave = waveFile.bextNeedsSave && writable.contains(.bext)
        waveFile.iXMLNeedsSave = waveFile.iXMLNeedsSave && writable.contains(.ixml)

        guard waveFile.save() else {
            guard !waveFile.failedComponents.contains(.container) else {
                throw MetadataError.saveFailed(url)
            }
            return waveFile.failedWrites
        }

        return []
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
        markerCollection.markerDescriptions.map { desc in
            desc.audioMarker(markerID: desc.markerID ?? -1, fileType: fileType, fileSampleRate: audioFormat?.sampleRate)
        }
    }
}
