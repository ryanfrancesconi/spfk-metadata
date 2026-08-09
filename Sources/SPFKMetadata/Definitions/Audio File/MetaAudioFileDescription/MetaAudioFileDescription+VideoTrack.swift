// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMatroska
import SPFKMetadataBase
import SPFKVideo

/// Sits alongside the TagLib-based path in `MetaAudioFileDescription+IO.swift` — TagLib
/// remains the source for all tag data (title/artist/genre/etc.); this is a purely additive,
/// parallel read path for video-technical and QuickTime-user-data fields only, delegating the
/// actual AVFoundation reads to `spfk-video`'s `VideoTrackReader`. Best-effort: failures leave
/// `videoTrack`/`quickTimeUserData` `nil` rather than failing the whole parse, matching how the
/// TagLib-based `load()` in `+IO.swift` treats its own reads as best-effort.
extension MetaAudioFileDescription {
    /// Public so callers beyond `init(parsing:)` (e.g. a store-level background backfill
    /// for elements saved before `videoTrack`/`quickTimeUserData` were added to this type's
    /// `Codable` conformance — see `shadowtag-video-metadata-plan.md`) can re-run this read.
    public mutating func loadVideoTrack() async {
        guard let fileType, fileType.isVideo else { return }

        // `readAnyContainer` rather than `read`: AVFoundation cannot open Matroska, so the plain
        // read returns a nil video track for a .mkv that plainly has one.
        let result = await VideoTrackReader.readAnyContainer(from: url)
        videoTrack = result.videoTrack
        quickTimeUserData = result.quickTimeUserData

        // Read here rather than in its own pass: a picker needs the list, and this is already the
        // one place that asks a file about its tracks without caring which container it is.
        audioTracks = await AudioTrackReader.readAnyContainer(from: url)
    }
}
