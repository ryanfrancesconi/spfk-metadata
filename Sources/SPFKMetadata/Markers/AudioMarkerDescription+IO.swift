// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
import SPFKMetadataC

extension AudioMarkerDescription {
    /// Creates a marker from a Core Audio RIFF cue point.
    public init(riffMarker marker: AudioMarker) {
        self.init(
            name: marker.name,
            startTime: marker.time,
            sampleRate: marker.sampleRate,
            markerID: Int(marker.markerID)
        )
    }

    /// Creates a marker from an ID3 or AVFoundation chapter marker.
    public init(chapterMarker marker: ChapterMarker) {
        self.init(
            name: marker.name,
            startTime: marker.startTime,
            endTime: marker.endTime
        )
    }

    /// Converts to a `ChapterMarker` for writing via format-specific utilities.
    public var chapterMarker: ChapterMarker {
        ChapterMarker(name: name ?? "Marker", startTime: startTime, endTime: endTime ?? startTime)
    }
}
