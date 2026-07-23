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
}
