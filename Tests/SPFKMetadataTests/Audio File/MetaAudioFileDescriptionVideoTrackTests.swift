import Foundation
@testable import SPFKMetadata
import SPFKBase
import Testing

/// Pure-function unit tests for the helpers behind `loadVideoTrack()`/
/// `loadQuickTimeUserData(asset:)` — no video fixture needed, since these don't touch
/// AVFoundation at all. See `shadowtag-video-metadata-plan.md`.
@Suite
struct MetaAudioFileDescriptionVideoTrackTests {
    // MARK: - parseISO6709

    @Test func parseISO6709ParsesPositiveLatitudeNegativeLongitude() {
        let result = MetaAudioFileDescription.parseISO6709("+37.3349-122.0090+000.000/")
        #expect(result.latitude == 37.3349)
        #expect(result.longitude == -122.0090)
    }

    @Test func parseISO6709ParsesNegativeLatitudePositiveLongitude() {
        let result = MetaAudioFileDescription.parseISO6709("-33.8688+151.2093/")
        #expect(result.latitude == -33.8688)
        #expect(result.longitude == 151.2093)
    }

    @Test func parseISO6709ParsesWithoutAltitude() {
        let result = MetaAudioFileDescription.parseISO6709("+45.3496-121.8368/")
        #expect(result.latitude == 45.3496)
        #expect(result.longitude == -121.8368)
    }

    @Test func parseISO6709ReturnsNilForMalformedString() {
        let result = MetaAudioFileDescription.parseISO6709("not a coordinate")
        #expect(result.latitude == nil)
        #expect(result.longitude == nil)
    }

    @Test func parseISO6709ReturnsNilForEmptyString() {
        let result = MetaAudioFileDescription.parseISO6709("")
        #expect(result.latitude == nil)
        #expect(result.longitude == nil)
    }

    // MARK: - rotationDegrees

    @Test func rotationDegreesIdentityTransformIsZero() {
        #expect(MetaAudioFileDescription.rotationDegrees(from: .identity) == 0)
    }

    @Test func rotationDegreesQuarterTurnClockwise() {
        // 90° clockwise: a portrait phone video's typical preferredTransform.
        let transform = CGAffineTransform(rotationAngle: .pi / 2)
        #expect(MetaAudioFileDescription.rotationDegrees(from: transform) == 90)
    }

    @Test func rotationDegreesHalfTurn() {
        let transform = CGAffineTransform(rotationAngle: .pi)
        #expect(MetaAudioFileDescription.rotationDegrees(from: transform) == 180)
    }

    @Test func rotationDegreesThreeQuarterTurn() {
        let transform = CGAffineTransform(rotationAngle: -.pi / 2)
        let degrees = MetaAudioFileDescription.rotationDegrees(from: transform)
        // -90° normalizes to 270°.
        #expect(degrees == 270)
    }

    @Test func rotationDegreesAlwaysNormalizesToMultipleOf90() {
        // A transform that isn't an exact multiple of 90° (e.g. a slight lens-correction
        // skew) should still snap to the nearest cardinal rotation, not return a raw angle.
        let transform = CGAffineTransform(rotationAngle: (.pi / 2) + 0.05)
        let degrees = MetaAudioFileDescription.rotationDegrees(from: transform)
        #expect(degrees % 90 == 0)
    }

    // MARK: - fourCCString

    @Test func fourCCStringDecodesAVC1() {
        // 'a','v','c','1' packed big-endian into a FourCharCode, matching how
        // CMFormatDescriptionGetMediaSubType actually returns codec identifiers.
        let fourCC: FourCharCode = 0x61766331
        #expect(MetaAudioFileDescription.fourCCString(fourCC) == "avc1")
    }

    @Test func fourCCStringDecodesHVC1() {
        let fourCC: FourCharCode = 0x68766331
        #expect(MetaAudioFileDescription.fourCCString(fourCC) == "hvc1")
    }

    @Test func fourCCStringReturnsNilForNonPrintableBytes() {
        // Byte 0x00 falls outside the printable ASCII range (0x20...0x7E) this function
        // requires, so it should refuse to decode rather than return garbage.
        let fourCC: FourCharCode = 0x00000000
        #expect(MetaAudioFileDescription.fourCCString(fourCC) == nil)
    }
}
