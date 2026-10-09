// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMatroska
import SPFKMetadataBase
import SPFKVideo

extension MetaAudioFileDescription {
    /// Reads video-technical fields, QuickTime user data, protection and the audio track listing;
    /// TagLib stays the source for tags. Best-effort: a failed read leaves the fields `nil` or empty.
    ///
    /// Stamps ``trackReaderVersion`` when the file was there to read, so a store's repair knows a
    /// read that found nothing from one that never ran. Public for that repair.
    public mutating func loadVideoTrack() async {
        guard let fileType, fileType.isVideo || fileType.supportsMultipleAudioTracks else { return }

        // An unreachable file answers nothing: recording its reads would persist "unprotected" and
        // "no tracks" for a file on an unmounted volume.
        guard url.exists else { return }

        if fileType.isVideo {
            // AVFoundation cannot open Matroska, so `read` returns no video track for a .mkv.
            let result = await VideoTrackReader.readAnyContainer(from: url)
            videoTrack = result.videoTrack
            quickTimeUserData = result.quickTimeUserData
            isProtected = result.hasProtectedContent
        }

        // Not gated on video: `.mka` and multi-track `.m4a` offer the same choice, and asking a WAV
        // costs an asset open per import.
        if fileType.supportsMultipleAudioTracks {
            // FairPlay audio (`.m4b`, `.m4a`) reaches no video read to be flagged there.
            if !fileType.isVideo {
                isProtected = await ProtectedContentReader.hasProtectedContent(url: url)
            }

            audioTracks = await AudioTrackReader.readAnyContainer(from: url)
        }

        trackReaderVersion = VideoTrackProperties.currentParserVersion
    }

    /// Takes every field ``loadVideoTrack()`` writes from `read`, a copy it ran on.
    public mutating func adoptTrackRead(from read: MetaAudioFileDescription) {
        videoTrack = read.videoTrack
        quickTimeUserData = read.quickTimeUserData
        isProtected = read.isProtected
        audioTracks = read.audioTracks
        trackReaderVersion = read.trackReaderVersion
    }
}
