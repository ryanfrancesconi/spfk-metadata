// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMatroska
import SPFKMetadataBase
import SPFKVideo

extension MetaAudioFileDescription {
    /// Reads video-technical fields, QuickTime user data and the audio track listing; TagLib stays
    /// the source for tags. Best-effort: a failed read leaves the fields `nil` or empty.
    ///
    /// Public for the stores' backfill of elements decoded before these fields existed.
    public mutating func loadVideoTrack() async {
        guard let fileType else { return }

        if fileType.isVideo {
            // AVFoundation cannot open Matroska, so `read` returns no video track for a .mkv.
            let result = await VideoTrackReader.readAnyContainer(from: url)
            videoTrack = result.videoTrack
            quickTimeUserData = result.quickTimeUserData
            isProtected = result.hasProtectedContent
        }

        // Not gated on video: `.mka` and multi-track `.m4a` offer the same choice, and asking a WAV
        // costs an asset open per import.
        guard fileType.supportsMultipleAudioTracks else { return }

        // FairPlay audio (`.m4b`, `.m4a`) reaches no video read to be flagged there.
        if !fileType.isVideo {
            isProtected = await ProtectedContentReader.hasProtectedContent(url: url)
        }

        audioTracks = await AudioTrackReader.readAnyContainer(from: url)
    }
}
