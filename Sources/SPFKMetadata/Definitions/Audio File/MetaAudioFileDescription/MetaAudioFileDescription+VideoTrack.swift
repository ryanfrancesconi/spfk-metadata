// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
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

        let result = await VideoTrackReader.read(from: url)
        videoTrack = result.videoTrack
        quickTimeUserData = result.quickTimeUserData
    }
}
