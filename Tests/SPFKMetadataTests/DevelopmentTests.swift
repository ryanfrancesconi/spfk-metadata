import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

// MARK: - M4A Unknown-format artwork investigation

#if os(macOS)
    /// Reproduces artwork stripping on M4A files where the covr atom uses CoverArt::Unknown format.
    /// TagLib's complexProperties("PICTURE") returns mimeType "image/" for Unknown-format items,
    /// which [UTType typeWithMIMEType:] can't resolve, causing buildPictureRef() to return nil.
    /// Without the JPEG fallback fix, imageDescription.cgImage is nil after parsing,
    /// and tagProperties.save() strips the artwork with nothing to restore.
    @Suite(.serialized, .tags(.development)) class M4AArtworkInvestigationTests: BinTestCase {
        let fixture = URL(filePath: "/Users/rf/Desktop/shadowtag-audio/SplitStemsTestPack/Designed/Riser/DSGNRise_RISE- War Stomp_B00M_CTRDS.m4a")

        /// Confirm the fixture has embedded artwork that TagLib can find.
        @Test func artworkIsDetectable() throws {
            guard fixture.exists else { return }
            let pictureRef = try TagPictureRef.parsing(url: fixture)
            #expect(pictureRef.cgImage.width > 0)
            #expect(pictureRef.cgImage.height > 0)
        }

        /// Parse the fixture and confirm cgImage is populated (requires buildPictureRef fix).
        @Test func parsePopulatesCGImage() async throws {
            guard fixture.exists else { return }
            let desc = try await MetaAudioFileDescription(parsing: fixture)
            #expect(desc.imageDescription.cgImage != nil)
        }

        /// Markers-only save must not strip artwork. Replicates the user's exact workflow:
        /// open file → add marker → save(dirtyFlags: [.markers]).
        @Test func markersOnlySavePreservesArtwork() async throws {
            guard fixture.exists else { return }
            let tmpfile = try copyToBin(url: fixture)

            // Confirm artwork before
            let originalRef = try TagPictureRef.parsing(url: tmpfile)
            let originalWidth = originalRef.cgImage.width
            #expect(originalWidth > 0)

            var desc = try await MetaAudioFileDescription(parsing: tmpfile)
            #expect(desc.imageDescription.cgImage != nil, "cgImage must be non-nil after parse")

            // Add a marker, save markers only
            desc.markerCollection.update(markerDescriptions: [
                AudioMarkerDescription(name: "Test Marker", startTime: 1.0)
            ])
            try desc.save(dirtyFlags: [.markers])

            let afterRef = try TagPictureRef.parsing(url: tmpfile)
            #expect(afterRef.cgImage.width == originalWidth, "artwork must survive markers-only save")
        }

        /// Metadata-only save must not strip artwork (the core regression).
        @Test func metadataOnlySavePreservesArtwork() async throws {
            guard fixture.exists else { return }
            let tmpfile = try copyToBin(url: fixture)

            let initial = try await MetaAudioFileDescription(parsing: tmpfile)
            let originalWidth = try #require(initial.imageDescription.cgImage?.width)
            #expect(originalWidth > 0)

            var updated = initial
            updated.tagProperties[.title] = "Artwork Preservation Test"
            try updated.save(dirtyFlags: [.metadata])

            let restoredRef = try TagPictureRef.parsing(url: tmpfile)
            #expect(restoredRef.cgImage.width == originalWidth)

            let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
            #expect(reloaded.tagProperties[.title] == "Artwork Preservation Test")
            #expect(reloaded.imageDescription.cgImage?.width == originalWidth)
        }

        /// Step-by-step diagnostic: trace every stage of the parse→save cycle
        /// to pinpoint exactly where artwork is lost.
        ///
        /// Steps checked independently:
        ///   1. TagPictureRef.parsing() succeeds (TagLib-level read)
        ///   2. MetaAudioFileDescription(parsing:) populates cgImage
        ///   3. imageDescription.pictureRef is non-nil (computed from cgImage)
        ///   4. tagProperties.save(to:) alone strips TagLib-level artwork (expected)
        ///   5. TagPicture.write(pictureRef:path:) restores artwork to the file
        ///   6. Full save(dirtyFlags:[.metadata]) round-trip leaves artwork intact
        @Test func deepExaminationOfSaveCycle() async throws {
            guard fixture.exists else { return }
            let tmpfile = try copyToBin(url: fixture)

            // Step 1: TagLib-level read
            let tagRef = try TagPictureRef.parsing(url: tmpfile)
            let originalWidth = tagRef.cgImage.width
            #expect(originalWidth > 0, "Step 1: TagPictureRef.parsing() must yield a valid CGImage")

            // Step 2: MetaAudioFileDescription parse populates cgImage
            let desc = try await MetaAudioFileDescription(parsing: tmpfile)
            #expect(desc.imageDescription.cgImage != nil, "Step 2: MetaAudioFileDescription must populate cgImage")
            #expect(desc.imageDescription.cgImage?.width == originalWidth, "Step 2: cgImage width must match TagLib read")

            // Step 3: pictureRef is computable (non-nil cgImage → non-nil pictureRef)
            #expect(desc.imageDescription.pictureRef != nil, "Step 3: pictureRef must be non-nil when cgImage is set")

            // Step 4: tagProperties.save() alone strips artwork (this is expected behaviour — TagLib strip clears all tags)
            let tmpfileForStripTest = try copyToBin(url: fixture)
            try TagProperties(url: tmpfileForStripTest).save(to: tmpfileForStripTest)
            let afterStripRef = try? TagPictureRef.parsing(url: tmpfileForStripTest)
            #expect(afterStripRef == nil, "Step 4: tagProperties.save() should strip existing artwork from file")

            // Step 5: TagPicture.write() restores artwork immediately after a strip
            let tmpfileForRestoreTest = try copyToBin(url: fixture)
            let capturedPictureRef = try #require(desc.imageDescription.pictureRef)
            try TagProperties(url: tmpfileForRestoreTest).save(to: tmpfileForRestoreTest)
            let writeResult = TagPicture.write(capturedPictureRef, path: tmpfileForRestoreTest.path)
            #expect(writeResult, "Step 5: TagPicture.write() must return true")
            let afterRestoreRef = try TagPictureRef.parsing(url: tmpfileForRestoreTest)
            #expect(afterRestoreRef.cgImage.width == originalWidth, "Step 5: artwork must be readable at TagLib level after explicit write")

            // Step 6: full metadata-only save round-trip
            var updated = desc
            updated.tagProperties[.title] = "Deep Exam Test"
            try updated.save(dirtyFlags: [.metadata])
            let finalRef = try TagPictureRef.parsing(url: tmpfile)
            #expect(finalRef.cgImage.width == originalWidth, "Step 6: artwork width must survive metadata-only save")
        }

        /// Examines the original fixture file in place — no copy.
        /// Reads are non-destructive; the save cycle operates on a separate copy.
        /// This reveals the actual on-disk state of the file independent of the copy process.
        @Test func deepExaminationOfOriginalFile() async throws {
            guard fixture.exists else { return }

            // Step 1: TagLib-level read on the original
            let tagRef = try TagPictureRef.parsing(url: fixture)
            let originalWidth = tagRef.cgImage.width
            #expect(originalWidth > 0, "Original Step 1: TagPictureRef.parsing() must yield a valid CGImage")

            // Step 2: MetaAudioFileDescription parse on the original
            let desc = try await MetaAudioFileDescription(parsing: fixture)
            #expect(desc.imageDescription.cgImage != nil, "Original Step 2: MetaAudioFileDescription must populate cgImage")
            #expect(desc.imageDescription.cgImage?.width == originalWidth, "Original Step 2: cgImage width must match TagLib read")

            // Step 3: pictureRef is computable from the original's cgImage
            let pictureRef = try #require(desc.imageDescription.pictureRef, "Original Step 3: pictureRef must be non-nil when cgImage is set")

            // Step 4: tagProperties.save() strips, then TagPicture.write() restores — on a copy
            let tmpfile = try copyToBin(url: fixture)
            try TagProperties(url: tmpfile).save(to: tmpfile)
            let afterStrip = try? TagPictureRef.parsing(url: tmpfile)
            #expect(afterStrip == nil, "Original Step 4: strip must remove artwork")
            let writeResult = TagPicture.write(pictureRef, path: tmpfile.path)
            #expect(writeResult, "Original Step 4: TagPicture.write() must return true after strip")
            let afterRestore = try TagPictureRef.parsing(url: tmpfile)
            #expect(afterRestore.cgImage.width == originalWidth, "Original Step 4: restore must write artwork with correct dimensions")

            // Step 5: full metadata-only save on a copy seeded from the original parse result
            let tmpfile2 = try copyToBin(url: fixture)
            var updated = try await MetaAudioFileDescription(parsing: tmpfile2)
            updated.tagProperties[.title] = "In-Place Exam Test"
            try updated.save(dirtyFlags: [.metadata])
            let finalRef = try TagPictureRef.parsing(url: tmpfile2)
            #expect(finalRef.cgImage.width == originalWidth, "Original Step 5: artwork must survive metadata-only save")
        }
    }
#endif

// MARK: - Malformed WAV investigation

#if os(macOS)
    /// Development tests to characterise how AVAudioFile and MetaAudioFileDescription behave
    /// with a WAV that has a wrong RIFF chunk size (data chunk outside declared boundary).
    @Suite(.tags(.development)) struct MalformedWAVInvestigationTests {
        let url = URL(filePath: "/Users/rf/Downloads/TestResources/invalid-chunk-size.wav")

        /// AVAudioFile opens without error but reports 0 frames — the data chunk lies outside
        /// the declared RIFF boundary so AVFoundation never finds it.
        @Test func avAudioFileReportsZeroFrames() throws {
            guard url.exists else { return }

            let audioFile = try AVAudioFile(forReading: url)
            #expect(audioFile.length == 0)
            #expect(audioFile.duration == 0.0)
            // Format header is still readable
            #expect(audioFile.fileFormat.sampleRate == 44100.0)
            #expect(audioFile.fileFormat.channelCount == 2)
        }

        /// MetaAudioFileDescription reads correct metadata via TagLib but marks the file
        /// as not AV-playable because AVAudioFile reports 0 frames.
        @Test func metaAudioFileDescriptionIsNotPlayable() async throws {
            guard url.exists else { return }

            let desc = try await MetaAudioFileDescription(parsing: url)
            // TagLib reads past the bad RIFF boundary — format properties are correct
            #expect(desc.audioFormat?.sampleRate == 44100.0)
            #expect(desc.audioFormat?.channelCount == 2)
            #expect((desc.audioFormat?.duration ?? 0) > 0)
            // AVAudioFile sees 0 frames — not playable
            #expect(desc.isAVPlayable == false)
        }
    }
#endif
