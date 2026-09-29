// Copyright Ryan Francesconi. All Rights Reserved.

import Darwin
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata
@testable import SPFKMetadataC

/// Round-trip rating tests for every supported format.
///
/// Ratings are stored in format-specific frames (not the generic PropertyMap),
/// accessed exclusively via TagRating's path-based interface.
/// The public API works in star counts (0 = unrated, 1–5 = rated).
///
/// Format storage:
///   - WAV/MP3/AIFF: POPM (ID3v2 Popularimeter), WMP canonical byte values
///   - FLAC/OGG: Xiph RATING (normalized int string) + FMPS_RATING (float string)
///   - M4A/MP4/AAC: `rate` atom + `----:com.apple.iTunes:RATING` freeform
@Suite(.tags(.file))
final class TagRatingTests: BinTestCase {
    // MARK: - WAV (POPM via ID3v2)

    @Test func wavRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        #expect(TagRating.write(4, toPath: tmp.path))

        let read = TagRating.read(tmp.path)
        #expect(read == 4)
    }

    @Test func wavRatingClearWithZero() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        #expect(TagRating.write(3, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 3)

        #expect(TagRating.write(0, toPath: tmp.path))
        let read = TagRating.read(tmp.path)
        #expect(read <= 0)
    }

    // MARK: - MP3 (POPM via ID3v2)

    @Test func mp3RatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        #expect(TagRating.write(5, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 5)
    }

    // MARK: - FLAC (Xiph RATING + FMPS_RATING)

    @Test func flacRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        #expect(TagRating.write(3, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 3)
    }

    // MARK: - M4A (rate atom + freeform)

    @Test func m4aRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        #expect(TagRating.write(2, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 2)
    }

    // MARK: - OGG Vorbis (Xiph RATING + FMPS_RATING) — macOS only

    #if os(macOS)
        @Test func oggRatingRoundTrip() async throws {
            let tmp = try copyToBin(url: TestBundleResources.shared.tabla_ogg)

            #expect(TagRating.write(4, toPath: tmp.path))
            #expect(TagRating.read(tmp.path) == 4)
        }
    #endif

    // MARK: - TagProperties (Swift integration layer)

    @Test func tagPropertiesMP3RatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        var props = TagProperties()
        props.data.tags[.rating] = "4"
        try props.save(to: tmp)

        var loaded = TagProperties()
        try loaded.load(url: tmp)
        #expect(loaded.data.tags[.rating] == "4")
    }

    @Test func tagPropertiesFLACRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        var props = TagProperties()
        props.data.tags[.rating] = "3"
        try props.save(to: tmp)

        var loaded = TagProperties()
        try loaded.load(url: tmp)
        #expect(loaded.data.tags[.rating] == "3")
    }

    // MARK: - Locale safety (FMPS_RATING integer arithmetic)

    /// Verifies that FMPS_RATING survives a write/read cycle even when the C locale
    /// formats decimals with commas. TagRating uses integer arithmetic (not snprintf)
    /// so the locale cannot produce "0,800" instead of "0.800".
    @Test func flacRatingLocaleInvariance() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let savedLocale = setlocale(LC_NUMERIC, nil).map { String(cString: $0) } ?? "C"
        _ = setlocale(LC_NUMERIC, "fr_FR.UTF-8") ?? setlocale(LC_NUMERIC, "fr_FR")
        defer { savedLocale.withCString { _ = setlocale(LC_NUMERIC, $0) } }

        #expect(TagRating.write(4, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 4)
    }

    // MARK: - Overwrite tests (write A, verify A, write B, verify B)

    @Test func wavRatingOverwrite() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_wav)
        #expect(TagRating.write(3, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 3)
        #expect(TagRating.write(4, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 4)
    }

    @Test func mp3RatingOverwrite() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        #expect(TagRating.write(3, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 3)
        #expect(TagRating.write(4, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 4)
    }

    @Test func flacRatingOverwrite() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        #expect(TagRating.write(3, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 3)
        #expect(TagRating.write(4, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 4)
    }

    @Test func m4aRatingOverwrite() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_m4a)
        #expect(TagRating.write(3, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 3)
        #expect(TagRating.write(4, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 4)
    }

    #if os(macOS)
        @Test func oggRatingOverwrite() async throws {
            let tmp = try copyToBin(url: TestBundleResources.shared.tabla_ogg)
            #expect(TagRating.write(3, toPath: tmp.path))
            #expect(TagRating.read(tmp.path) == 3)
            #expect(TagRating.write(4, toPath: tmp.path))
            #expect(TagRating.read(tmp.path) == 4)
        }
    #endif

    @Test func aiffRatingOverwrite() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_aif)
        #expect(TagRating.write(3, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 3)
        #expect(TagRating.write(4, toPath: tmp.path))
        #expect(TagRating.read(tmp.path) == 4)
    }

    // MARK: - Pre-rated fixture read tests

    // These verify the read path in isolation: fixtures were tagged by an external
    // Python script (mutagen + binary construction), not by TagRating.write.
    // All fixtures embed POPM byte=196 (4 stars) or Xiph RATING=80 (normalized 4 stars).

    @Test func wavFixtureRatingRead() throws {
        #expect(TagRating.read(TestBundleResources.shared.rated_80_wav.path) == 4)
    }

    @Test func mp3FixtureRatingRead() throws {
        #expect(TagRating.read(TestBundleResources.shared.rated_80_mp3.path) == 4)
    }

    @Test func flacFixtureRatingRead() throws {
        #expect(TagRating.read(TestBundleResources.shared.rated_80_flac.path) == 4)
    }

    @Test func m4aFixtureRatingRead() throws {
        #expect(TagRating.read(TestBundleResources.shared.rated_80_m4a.path) == 4)
    }

    #if os(macOS)
        @Test func oggFixtureRatingRead() throws {
            #expect(TagRating.read(TestBundleResources.shared.rated_80_ogg.path) == 4)
        }
    #endif

    @Test func aiffFixtureRatingRead() throws {
        #expect(TagRating.read(TestBundleResources.shared.rated_80_aif.path) == 4)
    }

    // MARK: - Every rating branch

    /// One case per container branch in `TagRating.mm`.
    enum RatingContainer: String, CaseIterable, Sendable {
        case mpeg, wav, aiff, flac, vorbis, opus, mp4, ape, wavPack, asf, matroska
    }

    private func file(for container: RatingContainer) throws -> URL {
        let resources = TestBundleResources.shared

        switch container {
        case .mpeg: return try copyToBin(url: resources.tabla_mp3)
        case .wav: return try copyToBin(url: resources.tabla_wav)
        case .aiff: return try copyToBin(url: resources.tabla_aif)
        case .flac: return try copyToBin(url: resources.tabla_flac)
        case .vorbis: return try copyToBin(url: resources.tabla_ogg)
        case .opus: return try copyToBin(url: resources.sine_opus)
        case .mp4: return try copyToBin(url: resources.tabla_m4a)
        case .ape: return try makeMonkeysAudioFile()
        case .wavPack: return try copyToBin(url: resources.sine_wv)
        case .asf: return try copyToBin(url: resources.sine_wma)
        case .matroska: return try copyToBin(url: resources.tabla_mka)
        }
    }

    /// A Monkey's Audio 3.99 descriptor and header with no frames, which TagLib opens as `APE::File`.
    private func makeMonkeysAudioFile() throws -> URL {
        var bytes = Data("MAC ".utf8)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        append(UInt16(3990)) // version
        append(UInt16(0)) // padding
        append(UInt32(52)) // descriptor bytes
        append(UInt32(24)) // header bytes
        bytes.append(Data(count: 36)) // seek table, header data, frame data sizes, MD5
        append(UInt16(2000)) // compression level
        append(UInt16(0)) // format flags
        append(UInt32(73728)) // blocks per frame
        append(UInt32(0)) // final frame blocks
        append(UInt32(0)) // total frames
        append(UInt16(16)) // bits per sample
        append(UInt16(1)) // channels
        append(UInt32(44100))

        let url = bin.appendingPathComponent("rating.ape")
        try bytes.write(to: url)
        return url
    }

    @Test(arguments: RatingContainer.allCases)
    func ratingRoundTripsAndClears(container: RatingContainer) throws {
        let url = try file(for: container)

        #expect(TagRating.write(4, toPath: url.path), "\(container)")
        #expect(TagRating.read(url.path) == 4, "\(container)")

        #expect(TagRating.write(0, toPath: url.path), "\(container)")
        #expect(TagRating.read(url.path) == -1, "\(container)")
    }

    /// TagLib opens an APE or WavPack file with an ID3v1 tag and no APE tag without creating one,
    /// so the write has to.
    @Test(arguments: [RatingContainer.ape, .wavPack])
    func ratingIsWrittenBesideAnID3v1Tag(container: RatingContainer) throws {
        let url = try file(for: container)
        var id3v1 = Data("TAG".utf8)
        id3v1.append(Data(count: 124))
        id3v1.append(255) // genre: none
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: id3v1)
        try handle.close()

        #expect(TagRating.write(4, toPath: url.path), "\(container)")
        #expect(TagRating.read(url.path) == 4, "\(container)")
    }

    // MARK: - A container with no rating branch

    /// A TrueAudio header TagLib opens as `TrueAudio::File`, which has no rating branch.
    private func makeTrueAudioFile() throws -> URL {
        var bytes = Data("TTA1".utf8)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        append(UInt16(1)) // PCM
        append(UInt16(1)) // channels
        append(UInt16(16)) // bits per sample
        append(UInt32(44100))
        append(UInt32(0)) // sample frames
        append(UInt32(0)) // header CRC
        bytes.append(Data(count: 64))

        let url = bin.appendingPathComponent("no-rating-branch.tta")
        try bytes.write(to: url)
        return url
    }

    @Test func ratingOnAContainerWithNoBranchFails() throws {
        let url = try makeTrueAudioFile()

        #expect(TagRating.write(4, toPath: url.path) == false)
        #expect(TagRating.write(0, toPath: url.path))
    }

    @Test func tagSaveWithRatingOnAContainerWithNoBranchFails() throws {
        let url = try makeTrueAudioFile()

        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = ["TITLE": "Title", "RATING": "4"]
        #expect(tagFile.save() == false)

        tagFile.dictionary = ["TITLE": "Title"]
        #expect(tagFile.save())
    }

    /// The copy reports the lost rating but still writes every other tag.
    @Test func tagCopyToAContainerWithNoBranchKeepsTheOtherTags() throws {
        let source = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let sourceFile = TagFile(path: source.path)
        sourceFile.dictionary = ["TITLE": "Copied", "RATING": "4"]
        #expect(sourceFile.save())

        let destination = try makeTrueAudioFile()
        let copied = TagLibBridge.copyTags(fromPath: source.path, toPath: destination.path)

        #expect(copied == false)
        #expect(TagLibBridge.getTitle(destination.path) == "Copied")
    }
}
