// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMatroska
import SPFKMetadataBase
import SPFKVideo

/// Sits alongside the TagLib-based path in `MetaAudioFileDescription+IO.swift` — TagLib
/// remains the source for all tag data (title/artist/genre/etc.); this is a purely additive,
/// parallel read path for video-technical fields, QuickTime user data and the file's audio track
/// listing, delegating the actual AVFoundation reads to `spfk-video`'s `VideoTrackReader` and
/// `AudioTrackReader`. Best-effort: failures leave `videoTrack`/`quickTimeUserData` `nil` and
/// `audioTracks` empty rather than failing the whole parse, matching how the TagLib-based `load()`
/// in `+IO.swift` treats its own reads as best-effort.
extension MetaAudioFileDescription {
    /// Public so callers beyond `init(parsing:)` (e.g. a store-level background backfill
    /// for elements saved before `videoTrack`/`quickTimeUserData` were added to this type's
    /// `Codable` conformance — see `shadowtag-video-metadata-plan.md`) can re-run this read.
    public mutating func loadVideoTrack() async {
        guard let fileType else { return }

        if fileType.isVideo {
            // `readAnyContainer` rather than `read`: AVFoundation cannot open Matroska, so the plain
            // read returns a nil video track for a .mkv that plainly has one.
            let result = await VideoTrackReader.readAnyContainer(from: url)
            videoTrack = result.videoTrack
            quickTimeUserData = result.quickTimeUserData
            isProtected = result.hasProtectedContent
        }

        // Read here rather than in its own pass: a picker needs the list, and this is already the
        // one place that asks a file about its tracks without caring which container it is.
        //
        // On its own gate, not the video one: a `.mka` or a multi-track `.m4a` is an audio file with
        // exactly the same choice to offer, and asking a WAV costs an asset open per import to name
        // the only track it has.
        guard fileType.supportsMultipleAudioTracks else { return }

        // The same family of containers holds FairPlay audio (`.m4b`, `.m4a`), and the video read
        // above is the only other place that asks. A protected file that reaches the waveform scan
        // fails every read of it, and reaches the transport next.
        if !fileType.isVideo {
            isProtected = await ProtectedContentReader.hasProtectedContent(url: url)
        }

        audioTracks = await AudioTrackReader.readAnyContainer(from: url)
    }
}
