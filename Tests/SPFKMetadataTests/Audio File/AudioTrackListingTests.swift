// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

/// Which files come back from an ordinary parse knowing their audio tracks.
///
/// The Audio Track menu reads `audioTracks` off the parsed description and offers nothing when it is
/// empty, so a listing that works in `AudioTrackReader` and never reaches the description is
/// indistinguishable from a file with one track.
@Suite(.tags(.file))
struct AudioTrackListingTests {
    /// `org.matroska.mka` conforms to `.audio`, not `.movie` — the reason a videoless Matroska file
    /// listed nothing while every other Matroska container listed fine.
    @Test func parsingAMatroskaAudioFilePopulatesItsAudioTracks() async throws {
        let description = try await MetaAudioFileDescription(
            parsing: TestBundleResources.shared.dualaudio_mka
        )

        #expect(description.videoTrack == nil)
        #expect(description.audioTracks.map(\.language) == ["eng", "jpn"])
    }

    /// The same shape one container over: an MPEG-4 audio file carries alternate tracks and is not
    /// a movie either.
    @Test func parsingAnMPEG4AudioFilePopulatesItsAudioTracks() async throws {
        let description = try await MetaAudioFileDescription(
            parsing: TestBundleResources.shared.dualaudio_m4a
        )

        #expect(description.videoTrack == nil)
        #expect(description.audioTracks.map(\.language) == ["eng", "jpn"])
    }

    /// A single track is still listed, because the menu is disabled by counting rows rather than by
    /// an absent list — and because an empty list is what marks an element for re-reading.
    @Test func listsASingleTrackFileToo() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.tabla_m4a)

        #expect(description.audioTracks.count == 1)
    }

    /// The gate reads the container rather than the track count: a WAV has exactly one stream, and
    /// asking AVFoundation about it costs an asset open on every imported file to name the track
    /// that would have played anyway.
    @Test func doesNotListTracksForASingleStreamContainer() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.tabla_wav)

        #expect(description.audioTracks.isEmpty)
    }
}
