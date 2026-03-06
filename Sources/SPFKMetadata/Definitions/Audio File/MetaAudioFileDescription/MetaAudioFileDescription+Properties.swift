// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreImage
import Foundation
import SPFKAudioBase
import SPFKMetadataC

extension MetaAudioFileDescription {
    /// Returns the embedded artwork if available, falling back to the file's Finder thumbnail.
    public var bestAvailableImage: CGImage? {
        imageDescription.cgImage ??
            url.bestImageRepresentation?.cgImage
    }

    /// The BPM (beats per minute) value from the `.bpm` tag. Setting this updates the underlying tag string.
    public var bpm: Bpm? {
        get {
            guard let rawValue = tagProperties.tags[.bpm]?.double else {
                return nil
            }

            return Bpm(rawValue)
        }

        set {
            tagProperties.tags[.bpm] = newValue?.stringValue
        }
    }

    /// Loudness values assembled from ID3/TXXX loudness tags (not from the BEXT chunk).
    public var loudnessDescription: LoudnessDescription {
        LoudnessDescription(
            loudnessIntegrated: tagProperties[.loudnessIntegrated]?.double,
            loudnessRange: tagProperties[.loudnessRange]?.double,
            maxTruePeakLevel: tagProperties[.loudnessTruePeak]?.float,
            maxMomentaryLoudness: tagProperties[.loudnessMaxMomentary]?.double,
            maxShortTermLoudness: tagProperties[.loudnessMaxShortTerm]?.double,
        )
    }

    /// Converts the ``markerCollection`` to an array of `AudioMarker` bridge objects for WAV file writing.
    public var audioMarkers: [AudioMarker] {
        var waveMarkers = [AudioMarker]()

        for i in 0 ..< markerCollection.markerDescriptions.count {
            let desc = markerCollection.markerDescriptions[i]

            waveMarkers.append(
                AudioMarker(
                    name: desc.name ?? "Marker",
                    time: desc.startTime,
                    sampleRate: audioFormat?.sampleRate ?? 0,
                    markerID: Int32(i)
                )
            )
        }

        return waveMarkers
    }
}
