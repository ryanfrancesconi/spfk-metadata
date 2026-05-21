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
/// Rating is stored in format-specific frames (not the generic PropertyMap):
///   - WAV/MP3/AIFF: POPM (ID3v2 Popularimeter) via WaveFileC or TagFile
///   - FLAC/OGG: Xiph RATING (int string) + FMPS_RATING (float string) via TagFile
///   - M4A/MP4/AAC: `rate` atom + `----:com.apple.iTunes:RATING` freeform via TagFile
@Suite(.serialized, .tags(.file))
final class TagRatingTests: BinTestCase {
    // MARK: - WaveFileC (WAV via POPM)

    @Test func wavRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        let writer = WaveFileC(path: tmp.path)
        writer.rating = NSNumber(value: 80)
        writer.markersNeedsSave = false
        writer.imageNeedsSave = false
        #expect(writer.save())

        let reader = WaveFileC(path: tmp.path)
        #expect(reader.load())
        #expect(reader.rating?.intValue == 80)
    }

    /// Writing rating 0 should clear an existing POPM frame.
    @Test func wavRatingClearWithZero() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_wav)

        let writer = WaveFileC(path: tmp.path)
        writer.rating = NSNumber(value: 60)
        writer.markersNeedsSave = false
        writer.imageNeedsSave = false
        #expect(writer.save())

        let mid = WaveFileC(path: tmp.path)
        #expect(mid.load())
        #expect(mid.rating?.intValue == 60)

        let clearer = WaveFileC(path: tmp.path)
        clearer.rating = NSNumber(value: 0)
        clearer.markersNeedsSave = false
        clearer.imageNeedsSave = false
        #expect(clearer.save())

        let reloaded = WaveFileC(path: tmp.path)
        #expect(reloaded.load())
        let cleared = reloaded.rating
        #expect(cleared == nil || cleared?.intValue == 0)
    }

    // MARK: - TagFile (MP3 via POPM)

    @Test func mp3RatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_mp3)

        let writer = TagFile(path: tmp.path)
        writer.dictionary = ["RATING": "100"]
        #expect(writer.save())

        let reader = TagFile(path: tmp.path)
        #expect(reader.load())
        #expect((reader.dictionary as? [String: String])?["RATING"].flatMap(Int.init) == 100)
    }

    // MARK: - TagFile (FLAC via Xiph RATING + FMPS_RATING)

    @Test func flacRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let writer = TagFile(path: tmp.path)
        writer.dictionary = ["RATING": "60"]
        #expect(writer.save())

        let reader = TagFile(path: tmp.path)
        #expect(reader.load())
        #expect((reader.dictionary as? [String: String])?["RATING"].flatMap(Int.init) == 60)
    }

    // MARK: - TagFile (M4A via rate atom + freeform)

    @Test func m4aRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_m4a)

        let writer = TagFile(path: tmp.path)
        writer.dictionary = ["RATING": "40"]
        #expect(writer.save())

        let reader = TagFile(path: tmp.path)
        #expect(reader.load())
        #expect((reader.dictionary as? [String: String])?["RATING"].flatMap(Int.init) == 40)
    }

    // MARK: - TagFile (OGG Vorbis via Xiph RATING + FMPS_RATING) — macOS only

    #if os(macOS)
    @Test func oggRatingRoundTrip() async throws {
        let tmp = try copyToBin(url: TestBundleResources.shared.tabla_ogg)

        let writer = TagFile(path: tmp.path)
        writer.dictionary = ["RATING": "80"]
        #expect(writer.save())

        let reader = TagFile(path: tmp.path)
        #expect(reader.load())
        #expect((reader.dictionary as? [String: String])?["RATING"].flatMap(Int.init) == 80)
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

        // Try to activate a comma-decimal locale; falls back silently if unavailable.
        let savedLocale = setlocale(LC_NUMERIC, nil).map { String(cString: $0) } ?? "C"
        _ = setlocale(LC_NUMERIC, "fr_FR.UTF-8") ?? setlocale(LC_NUMERIC, "fr_FR")
        defer { savedLocale.withCString { _ = setlocale(LC_NUMERIC, $0) } }

        let writer = TagFile(path: tmp.path)
        writer.dictionary = ["RATING": "80"]
        #expect(writer.save())

        let reader = TagFile(path: tmp.path)
        #expect(reader.load())
        #expect((reader.dictionary as? [String: String])?["RATING"].flatMap(Int.init) == 80)
    }
}
