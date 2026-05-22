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
/// Rating is stored in format-specific frames (not the generic PropertyMap),
/// accessed exclusively via TagRatingUtil's path-based interface:
///   - WAV/MP3/AIFF: POPM (ID3v2 Popularimeter)
///   - FLAC/OGG: Xiph RATING (int string) + FMPS_RATING (float string)
///   - M4A/MP4/AAC: `rate` atom + `----:com.apple.iTunes:RATING` freeform
@Suite(.serialized, .tags(.file))
final class TagRatingTests: BinTestCase {
    // MARK: - WAV (POPM via ID3v2)

    @Test func wavRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        #expect(TagRatingUtil.writeRating(80, toPath: tmp.path))

        let read = TagRatingUtil.readRating(tmp.path)
        #expect(read == 80)
    }

    @Test func wavRatingClearWithZero() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        #expect(TagRatingUtil.writeRating(60, toPath: tmp.path))
        #expect(TagRatingUtil.readRating(tmp.path) == 60)

        #expect(TagRatingUtil.writeRating(0, toPath: tmp.path))
        let read = TagRatingUtil.readRating(tmp.path)
        #expect(read <= 0)
    }

    // MARK: - MP3 (POPM via ID3v2)

    @Test func mp3RatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        #expect(TagRatingUtil.writeRating(100, toPath: tmp.path))
        #expect(TagRatingUtil.readRating(tmp.path) == 100)
    }

    // MARK: - FLAC (Xiph RATING + FMPS_RATING)

    @Test func flacRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        #expect(TagRatingUtil.writeRating(60, toPath: tmp.path))
        #expect(TagRatingUtil.readRating(tmp.path) == 60)
    }

    // MARK: - M4A (rate atom + freeform)

    @Test func m4aRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        #expect(TagRatingUtil.writeRating(40, toPath: tmp.path))
        #expect(TagRatingUtil.readRating(tmp.path) == 40)
    }

    // MARK: - OGG Vorbis (Xiph RATING + FMPS_RATING) — macOS only

    #if os(macOS)
    @Test func oggRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_ogg)

        #expect(TagRatingUtil.writeRating(80, toPath: tmp.path))
        #expect(TagRatingUtil.readRating(tmp.path) == 80)
    }
    #endif

    // MARK: - TagProperties (Swift integration layer)

    @Test func tagPropertiesMP3RatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        var props = TagProperties()
        props.data.tags[.rating] = "80"
        try props.save(to: tmp)

        var loaded = TagProperties()
        try loaded.load(url: tmp)
        #expect(loaded.data.tags[.rating] == "80")
    }

    @Test func tagPropertiesFLACRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        var props = TagProperties()
        props.data.tags[.rating] = "60"
        try props.save(to: tmp)

        var loaded = TagProperties()
        try loaded.load(url: tmp)
        #expect(loaded.data.tags[.rating] == "60")
    }

    // MARK: - Locale safety (FMPS_RATING integer arithmetic)

    /// Verifies that FMPS_RATING survives a write/read cycle even when the C locale
    /// formats decimals with commas. TagRatingUtil uses integer arithmetic (not snprintf)
    /// so the locale cannot produce "0,800" instead of "0.800".
    @Test func flacRatingLocaleInvariance() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let savedLocale = setlocale(LC_NUMERIC, nil).map { String(cString: $0) } ?? "C"
        _ = setlocale(LC_NUMERIC, "fr_FR.UTF-8") ?? setlocale(LC_NUMERIC, "fr_FR")
        defer { savedLocale.withCString { _ = setlocale(LC_NUMERIC, $0) } }

        #expect(TagRatingUtil.writeRating(80, toPath: tmp.path))
        #expect(TagRatingUtil.readRating(tmp.path) == 80)
    }
}
