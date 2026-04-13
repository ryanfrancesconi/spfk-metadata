import AVFoundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import SPFKUtils
import Testing

@Suite(.serialized, .tags(.file))
class MetaAudioFileDescriptionTests: BinTestCase {
    @Test func codableRoundTrip() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let mafDescription = try await MetaAudioFileDescription(parsing: url)
        #expect(mafDescription.tagProperties.tags.count == 28)

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(mafDescription)
        let newObject = try PropertyListDecoder().decode(MetaAudioFileDescription.self, from: data)

        #expect(newObject == mafDescription)
    }

    @Test func saveRoundTrip() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)
        var mafDescription = try await MetaAudioFileDescription(parsing: url)

        let cgImage = try #require(try? await CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich))
        await mafDescription.imageDescription.update(cgImage: cgImage)
        mafDescription.imageDescription.description = "A NEW DESCRIPTION"
        mafDescription.tagProperties[.title] = "NEW TITLE"
        try mafDescription.save(dirtyFlags: [.metadata, .image])

        let updated = try await MetaAudioFileDescription(parsing: url)
        #expect(updated.tagProperties[.title] == "NEW TITLE")
        #expect(updated.imageDescription.cgImage?.width == cgImage.width)
        #expect(updated.imageDescription.description == "A NEW DESCRIPTION")
    }

    @Test func printFormats() async throws {
        for url in TestBundleResources.shared.formats {
            let maf = try await MetaAudioFileDescription(parsing: url)

            Log.debug(maf.fileType, maf.audioFormat?.formatDescription)

            let estimatedDataRate = try await AVAudioFile(forReading: url).estimatedDataRate()
            Log.debug(estimatedDataRate)
        }
    }

    @Test func parseBEXT() async throws {
        let url = TestBundleResources.shared.cowbell_bext_wav
        let maf = try await MetaAudioFileDescription(parsing: url)

        let bext = try #require(maf.bextDescription)

        Log.debug(bext)
    }
}

// MARK: - WAV chunk preservation

/// Tests that BEXT, iXML, and marker chunks survive a metadata-only save.
/// The underlying question is whether TagLib's WAV save preserves chunks it doesn't manage
/// (smpl/cue for markers) and correctly re-writes chunks it does manage (BEXT, iXML)
/// when they are passed through from the loaded MetaAudioFileDescription.
@Suite(.serialized, .tags(.file))
class MetaAudioFileDescriptionWAVChunkTests: BinTestCase {
    /// BEXT data must survive a metadata-only save.
    /// saveWave always passes bextDescription back to WaveFileC, so TagLib re-writes it.
    @Test func bextPreservedAcrossMetadataOnlySave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)

        let initial = try await MetaAudioFileDescription(parsing: tmpfile)
        let bext = try #require(initial.bextDescription)

        var updated = initial
        updated.tagProperties[.title] = "BEXT Preservation Test"
        try updated.save(dirtyFlags: [.metadata])

        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reloaded.bextDescription == bext)
        #expect(reloaded.tagProperties[.title] == "BEXT Preservation Test")
    }

    /// iXML chunk data must survive a metadata-only save.
    @Test func iXMLPreservedAcrossMetadataOnlySave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.ixml_chunk)

        let initial = try await MetaAudioFileDescription(parsing: tmpfile)
        let ixml = try #require(initial.iXMLMetadata)
        #expect(ixml.isEmpty == false)

        var updated = initial
        updated.tagProperties[.title] = "iXML Preservation Test"
        try updated.save(dirtyFlags: [.metadata])

        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reloaded.iXMLMetadata != nil)
        #expect(reloaded.tagProperties[.title] == "iXML Preservation Test")
    }

    /// Markers (smpl/cue chunks) must survive a metadata-only save.
    /// TagLib's WAV save must not strip AudioToolbox-written chunks it doesn't manage.
    @Test func markersPreservedAcrossMetadataOnlySave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        // Establish initial marker count and add one via WaveFileC
        let markerFile = WaveFileC(path: tmpfile.path)
        #expect(markerFile.load())
        let initialCount = markerFile.markers.count
        markerFile.markers.append(AudioMarker(name: "Test Marker", time: 1.0, sampleRate: 44100, markerID: 0))
        markerFile.markersNeedsSave = true
        markerFile.imageNeedsSave = false
        #expect(markerFile.save())

        let expectedCount = initialCount + 1

        // Parse with MetaAudioFileDescription and verify the marker was loaded
        let initial = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(initial.markerCollection.markerDescriptions.count == expectedCount)

        // Metadata-only save — markers must survive on disk (TagLib must preserve smpl/cue chunks)
        var updated = initial
        updated.tagProperties[.title] = "Marker Preservation Test"
        try updated.save(dirtyFlags: [.metadata])

        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reloaded.markerCollection.markerDescriptions.count == expectedCount)
        #expect(reloaded.tagProperties[.title] == "Marker Preservation Test")
    }
}

// MARK: - Artwork preservation

/// Tests that metadata-only saves don't discard embedded artwork, and that
/// clearing artwork in memory removes it from disk.
@Suite(.serialized, .tags(.file))
class MetaAudioFileDescriptionArtworkTests: BinTestCase {
    /// Saving with .metadata only must not strip existing embedded artwork (non-WAV).
    @Test func metadataOnlySavePreservesArtwork() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        // Embed artwork
        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        let cgImage = try #require(try? await CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich))
        await maf.imageDescription.update(cgImage: cgImage)
        maf.tagProperties[.title] = "Original"
        try maf.save(dirtyFlags: [.metadata, .image])

        // Confirm artwork is present
        let withArtwork = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(withArtwork.imageDescription.cgImage != nil)

        // Save metadata only — artwork must survive
        var updated = withArtwork
        updated.tagProperties[.title] = "Updated"
        try updated.save(dirtyFlags: [.metadata])

        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reloaded.tagProperties[.title] == "Updated")
        #expect(reloaded.imageDescription.cgImage != nil)
        #expect(reloaded.imageDescription.cgImage?.width == cgImage.width)
    }

    /// Setting cgImage to nil and saving must remove embedded artwork from the file (non-WAV).
    /// Verified at the TagLib level because MetaAudioFileDescription.updateDefaultImage()
    /// always fills cgImage with a fallback image when no embedded artwork is found.
    @Test func clearingArtworkRemovesItFromFile() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        // Embed artwork
        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        let cgImage = try #require(try? await CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich))
        await maf.imageDescription.update(cgImage: cgImage)
        try maf.save(dirtyFlags: [.metadata, .image])

        // Confirm embedded at TagLib level
        #expect(throws: Never.self) { try TagPictureRef.parsing(url: tmpfile) }

        // Clear artwork and save
        var loaded = try await MetaAudioFileDescription(parsing: tmpfile)
        loaded.imageDescription.cgImage = nil
        try loaded.save(dirtyFlags: [.metadata, .image])

        // Embedded artwork must be gone (TagLib level — avoids updateDefaultImage fallback)
        #expect(throws: (any Error).self) { try TagPictureRef.parsing(url: tmpfile) }
    }

    /// Saving with .metadata only must not strip existing embedded artwork (WAV).
    @Test func wavMetadataOnlySavePreservesArtwork() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        // Embed artwork
        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        let cgImage = try #require(try? await CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich))
        await maf.imageDescription.update(cgImage: cgImage)
        maf.tagProperties[.title] = "Original"
        try maf.save(dirtyFlags: [.metadata, .image])

        // Confirm artwork is present
        let withArtwork = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(withArtwork.imageDescription.cgImage != nil)

        // Save metadata only — artwork must survive
        var updated = withArtwork
        updated.tagProperties[.title] = "Updated"
        try updated.save(dirtyFlags: [.metadata])

        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reloaded.tagProperties[.title] == "Updated")
        #expect(reloaded.imageDescription.cgImage != nil)
        #expect(reloaded.imageDescription.cgImage?.width == cgImage.width)
    }

    /// Clearing artwork in a WAV file must remove it from disk.
    /// Verified at the TagLib level because MetaAudioFileDescription.updateDefaultImage()
    /// always fills cgImage with a fallback image when no embedded artwork is found.
    @Test func wavClearingArtworkRemovesItFromFile() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        // Embed artwork
        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        let cgImage = try #require(try? await CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich))
        await maf.imageDescription.update(cgImage: cgImage)
        try maf.save(dirtyFlags: [.metadata, .image])

        // Confirm embedded at TagLib level
        #expect(throws: Never.self) { try TagPictureRef.parsing(url: tmpfile) }

        // Clear artwork and save
        var loaded = try await MetaAudioFileDescription(parsing: tmpfile)
        loaded.imageDescription.cgImage = nil
        try loaded.save(dirtyFlags: [.metadata, .image])

        // Embedded artwork must be gone (TagLib level — avoids updateDefaultImage fallback)
        #expect(throws: (any Error).self) { try TagPictureRef.parsing(url: tmpfile) }
    }
}
