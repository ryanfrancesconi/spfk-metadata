// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

/// Matroska (`.mkv` / `.webm`) support.
///
/// TagLib 2.x ships a complete Matroska implementation and `FileRef` dispatches the extension, so
/// the container needed no format-specific read or write path — only the Swift-side vocabulary that
/// was gating it. These tests pin that the gate is really open, because the failure mode if it
/// closes again is silent: `AudioFileType(pathExtension:)` returns nil, `fileType` goes nil, and
/// every capability check downstream fails closed while the file still imports and displays.
///
/// **AVFoundation cannot open Matroska** (absent from `AVURLAsset.audiovisualTypes()`), so anything
/// here that works is going through TagLib.
@Suite(.tags(.file))
struct MatroskaTests {
    // MARK: - Vocabulary

    @Test func matroskaExtensionsResolveToAFileType() {
        #expect(AudioFileType(pathExtension: "mkv") == .mkv)
        #expect(AudioFileType(pathExtension: "webm") == .webm)
        #expect(AudioFileType(pathExtension: "MKV") == .mkv)
    }

    /// `isVideo` derives from UTType conformance rather than a hand-written list, so this asserts
    /// macOS really does declare the type — it is `org.matroska.mkv`, conforming to `.movie`.
    @Test func matroskaIsRecognizedAsVideo() {
        #expect(AudioFileType.mkv.isVideo)
        #expect(AudioFileType.webm.isVideo)
        #expect(!AudioFileType.mkv.isAudio)
    }

    /// The gate that was actually closed. Without this, `supportsMetadata` is false and the whole
    /// tag path is skipped for a file TagLib reads perfectly well.
    @Test func matroskaSupportsMetadata() {
        #expect(AudioFileType.mkv.supportsMetadata)
        #expect(AudioFileType.webm.supportsMetadata)
    }

    /// Deliberately excluded. Matroska has no XMP smart handler and is not RIFF, so claiming either
    /// would route writes into a path that cannot serve them.
    @Test func matroskaClaimsNeitherXMPNorRIFFChunks() {
        #expect(!AudioFileType.mkv.supportsXMP)
        #expect(!AudioFileType.mkv.supportsBEXT)
        #expect(!AudioFileType.mkv.supportsIXML)
        #expect(!AudioFileType.webm.supportsXMP)
    }

    /// AVFoundation cannot write Matroska, so nothing may offer it as a conversion target or hand
    /// it to `AVAudioFile`.
    @Test func matroskaIsNotOfferedAsAWriteTarget() {
        #expect(AudioFileType.mkv.avFileType == nil)
        #expect(!AudioFileType.mkv.isAVAudioFileWritable)
        #expect(AudioFileType.mkv.audioFileTypeID == nil)
    }

    @Test func matroskaMapsToATagLibParser() {
        #expect(AudioFileType.mkv.tagType == .matroska)
        #expect(AudioFileType.webm.tagType == .webm)
    }

    // MARK: - Real file

    @Test func readsTagsFromARealMatroskaFile() throws {
        let url = TestBundleResources.shared.sample_mkv

        var properties = TagProperties()
        try properties.load(url: url)

        #expect(properties[.title] == "SPFK Sample Matroska")
        #expect(properties[.artist] == "Spongefork")
    }

    /// The write half, and the one worth proving on a real container: TagLib re-serializes the
    /// whole Matroska file to change a tag, so a round trip that survives is evidence the write
    /// path is genuinely wired rather than silently no-oping.
    @Test func writesTagsToARealMatroskaFile() throws {
        let source = TestBundleResources.shared.sample_mkv
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkv-write-\(UUID().uuidString).mkv")
        try FileManager.default.copyItem(at: source, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }

        var properties = TagProperties()
        try properties.load(url: copy)
        properties[.title] = "Rewritten"
        properties[.comment] = "written by SPFKMetadataTests"
        try properties.save(to: copy)

        var readBack = TagProperties()
        try readBack.load(url: copy)

        #expect(readBack[.title] == "Rewritten")
        #expect(readBack[.comment] == "written by SPFKMetadataTests")
        // The untouched tag has to survive the rewrite, or a save is quietly destructive.
        #expect(readBack[.artist] == "Spongefork")
    }

    /// Rating is the one tag that does **not** travel in the PropertyMap: `TagFile.save` pulls
    /// `RATING` out and routes it through `TagRatingWriteToFile`, which had no Matroska branch — so
    /// a rating was read correctly, accepted by the editor, and then silently dropped on save.
    ///
    /// The write is read-modify-write on the property map, so this also has to prove the tags
    /// written moments earlier in the same save survive it.
    @Test func writesARatingToARealMatroskaFile() throws {
        let source = TestBundleResources.shared.sample_mkv
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkv-rating-\(UUID().uuidString).mkv")
        try FileManager.default.copyItem(at: source, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }

        var properties = TagProperties()
        try properties.load(url: copy)
        properties[.rating] = "4"
        properties[.keywords] = "one, two"
        try properties.save(to: copy)

        var readBack = TagProperties()
        try readBack.load(url: copy)

        #expect(readBack[.rating] == "4")
        #expect(readBack[.keywords] == "one, two")
        #expect(readBack[.title] == "SPFK Sample Matroska")
        #expect(readBack[.artist] == "Spongefork")
    }

    /// Clearing has to reach the file too, or a rating the user removed comes back on reload.
    @Test func clearingARatingRemovesItFromTheFile() throws {
        let source = TestBundleResources.shared.sample_mkv
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkv-rating-clear-\(UUID().uuidString).mkv")
        try FileManager.default.copyItem(at: source, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }

        var properties = TagProperties()
        try properties.load(url: copy)
        properties[.rating] = "5"
        try properties.save(to: copy)

        var cleared = TagProperties()
        try cleared.load(url: copy)
        cleared[.rating] = nil
        try cleared.save(to: copy)

        var readBack = TagProperties()
        try readBack.load(url: copy)

        #expect(readBack[.rating] == nil)
        #expect(readBack[.title] == "SPFK Sample Matroska")
    }

    // MARK: - Parsing without AVFoundation

    /// The gate that kept Matroska out of an audio-primary application: `init(parsing:)` opened
    /// every non-WAV file with `AVAudioFile` and threw when it could not, so a `.mkv` was accepted
    /// by the import filter and then failed to parse.
    ///
    /// AVFoundation genuinely cannot open this container — asserted here rather than assumed,
    /// because the fallback below is only meaningful if this is still true.
    @Test func avFoundationCannotOpenMatroska() {
        #expect(throws: (any Error).self) {
            try AVAudioFile(forReading: TestBundleResources.shared.sample_mkv)
        }
    }

    /// TagLib supplies the stream properties AVFoundation would have, so the row is populated
    /// rather than empty.
    @Test func parsingFallsBackToTagLibForStreamProperties() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.sample_mkv)

        #expect(description.fileType == .mkv)
        #expect(description.tag(for: .title) == "SPFK Sample Matroska")
        #expect(description.tag(for: .artist) == "Spongefork")

        let format = try #require(description.audioFormat)
        #expect(format.sampleRate > 0)
        #expect(format.channelCount > 0)
    }

    /// Not playable, and the row has to say so: this is what lights the `.playSlash` status icon
    /// and makes the editor show its warning instead of fetching a waveform that cannot exist.
    @Test func aMatroskaFileParsesAsNotPlayable() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.sample_mkv)
        #expect(description.isAVPlayable == false)
    }

    /// The fallback must not turn every unreadable file into a row. A file AVFoundation refuses
    /// *and* TagLib cannot read has nothing behind it, so the original failure stays the answer.
    @Test func aFileNeitherReaderCanOpenStillThrows() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-audio-\(UUID().uuidString).mkv")
        try Data("this is not a matroska file".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: (any Error).self) {
            try await MetaAudioFileDescription(parsing: url)
        }
    }

    /// The file must still be a valid Matroska container after a write — a rewrite that corrupts
    /// the container would still read back through TagLib's own parser, so assert the type is
    /// detectable from the bytes rather than from the extension.
    @Test func theContainerSurvivesAWrite() throws {
        let source = TestBundleResources.shared.sample_mkv
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkv-integrity-\(UUID().uuidString)") // no extension, on purpose
        try FileManager.default.copyItem(at: source, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }

        var properties = TagProperties()
        try properties.load(url: copy)
        properties[.title] = "Integrity"
        try properties.save(to: copy)

        // Extensionless, so this can only come from header inspection.
        #expect(TagFileType.detect(copy.path) == .matroska)
    }

    // MARK: - Video track

    /// Closes the resolution gap: `VideoTrackReader` returns nothing for Matroska because
    /// AVFoundation cannot open the container, which is why a `.mkv` row showed a blank Resolution
    /// while its tags read fine. `loadVideoTrack()` now falls back to the demuxer, and this asserts
    /// the fallback runs as part of an ordinary parse rather than needing a special call.
    @Test func parsingAMatroskaFilePopulatesTheVideoTrack() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.sample_mkv)
        let videoTrack = try #require(description.videoTrack)

        #expect(videoTrack.width == 160)
        #expect(videoTrack.height == 120)
        #expect(videoTrack.codec == "avc1")
    }

    /// The Audio Track menu reads `audioTracks` off the parsed description, so testing
    /// `AudioTrackReader` alone would pass while the shipping path returned nothing. Asserts the
    /// list arrives from an ordinary parse, for a container AVFoundation cannot open at all.
    @Test func parsingAMatroskaFilePopulatesItsAudioTracks() async throws {
        let description = try await MetaAudioFileDescription(
            parsing: TestBundleResources.shared.sample_dualaudio_mkv
        )

        #expect(description.audioTracks.map(\.language) == ["eng", "jpn"])
    }

    /// The `.mkv` is `sample.mov` remuxed with `-c copy`, so the two must report the same stream.
    /// Comparing the containers against each other keeps this honest if the fixture is ever
    /// regenerated at a different size.
    @Test func matroskaAndQuickTimeAgreeOnTheSameStream() async throws {
        let matroska = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.sample_mkv)
        let quickTime = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.sample_mov)

        #expect(matroska.videoTrack?.width == quickTime.videoTrack?.width)
        #expect(matroska.videoTrack?.height == quickTime.videoTrack?.height)
        #expect(matroska.videoTrack?.codec == quickTime.videoTrack?.codec)
    }

    /// The fallback fills the video track only. QuickTime user data is a `moov`-atom concept with
    /// no Matroska equivalent, so it stays nil rather than being faked from segment tags.
    @Test func theMatroskaFallbackDoesNotInventQuickTimeUserData() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.sample_mkv)
        #expect(description.quickTimeUserData == nil)
    }
}
