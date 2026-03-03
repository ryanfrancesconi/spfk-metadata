// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreImage
import Foundation
import SPFKAudioBase
import SPFKMetadataC

extension MetaAudioFileDescription {
    public var bestAvailableImage: CGImage? {
        imageDescription.cgImage ??
            url.bestImageRepresentation?.cgImage
    }

    public var tempo: Bpm? {
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

    /// From TagProperties metadata not BEXT
    public var loudnessDescription: LoudnessDescription {
        LoudnessDescription(
            loudnessIntegrated: tagProperties[.loudnessIntegrated]?.double,
            loudnessRange: tagProperties[.loudnessRange]?.double,
            maxTruePeakLevel: tagProperties[.loudnessTruePeak]?.float,
            maxMomentaryLoudness: tagProperties[.loudnessMaxMomentary]?.double,
            maxShortTermLoudness: tagProperties[.loudnessMaxShortTerm]?.double,
        )
    }

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
