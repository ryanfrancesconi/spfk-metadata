// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

@preconcurrency import AEXML
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase

extension IXMLMetadata {
    /// Generates an iXML string from the current properties.
    ///
    /// Only non-nil properties are included in the output.
    public var xml: String {
        let doc = AEXMLDocument()
        let root = doc.addChild(name: IXMLElement.bwfxml.rawValue)

        // Top-level elements
        addIfPresent(to: root, .ixmlVersion, version)
        addIfPresent(to: root, .project, project)
        addIfPresent(to: root, .scene, scene)
        addIfPresent(to: root, .take, take)
        addIfPresent(to: root, .tape, tape)
        addIfPresent(to: root, .familyUID, familyUID)
        addIfPresent(to: root, .familyName, familyName)
        addIfPresent(to: root, .fileUID, fileUID)
        addIfPresent(to: root, .note, note)
        addIfPresent(to: root, .circled, circled)
        addIfPresent(to: root, .wildTrack, wildTrack)

        // SPEED container
        if hasSpeedContent {
            let speed = root.addChild(name: IXMLElement.speed.rawValue)
            addIfPresent(to: speed, .masterSpeed, masterSpeed)
            addIfPresent(to: speed, .currentSpeed, currentSpeed)
            addIfPresent(to: speed, .timecodeRate, timecodeRate)
            addIfPresent(to: speed, .timecodeFlag, timecodeFlag)
            addIfPresent(to: speed, .fileSampleRate, fileSampleRate)
            addIfPresent(to: speed, .audioBitDepth, audioBitDepth)
            addIfPresent(to: speed, .digitizerSampleRate, digitizerSampleRate)
            addIfPresent(to: speed, .timestampSamplesSinceMidnightHi, timestampSamplesSinceMidnightHi)
            addIfPresent(to: speed, .timestampSamplesSinceMidnightLo, timestampSamplesSinceMidnightLo)
            addIfPresent(to: speed, .timestampSampleRate, timestampSampleRate)
        }

        // TRACK_LIST container
        if let tracks, tracks.isNotEmpty {
            let trackList = root.addChild(name: IXMLElement.trackList.rawValue)
            trackList.addChild(name: IXMLElement.trackCount.rawValue, value: "\(tracks.count)")

            for track in tracks {
                let trackElement = trackList.addChild(name: IXMLElement.track.rawValue)
                addIfPresent(to: trackElement, .channelIndex, track.channelIndex)
                addIfPresent(to: trackElement, .interleaveIndex, track.interleaveIndex)
                addIfPresent(to: trackElement, .name, track.name)
                addIfPresent(to: trackElement, .function, track.function)
            }
        }

        // LOUDNESS container
        if let loudness = loudnessDescription, loudness.isValid {
            let loudnessElement = root.addChild(name: IXMLElement.loudness.rawValue)

            addIfPresent(to: loudnessElement, .loudnessValue, loudness.loudnessIntegrated)
            addIfPresent(to: loudnessElement, .loudnessRange, loudness.loudnessRange)
            addIfPresent(to: loudnessElement, .maxTruePeakLevel, loudness.maxTruePeakLevel.map(Double.init))
            addIfPresent(to: loudnessElement, .maxMomentary, loudness.maxMomentaryLoudness)
            addIfPresent(to: loudnessElement, .maxShortTerm, loudness.maxShortTermLoudness)
        }

        // BEXT container
        if hasBextContent {
            let bext = root.addChild(name: IXMLElement.bext.rawValue)
            addIfPresent(to: bext, .bextVersion, bextVersion)
            addIfPresent(to: bext, .bextDescription, bextDescriptionText)
            addIfPresent(to: bext, .bextOriginator, bextOriginator)
            addIfPresent(to: bext, .bextOriginatorReference, bextOriginatorReference)
            addIfPresent(to: bext, .bextOriginationDate, bextOriginationDate)
            addIfPresent(to: bext, .bextOriginationTime, bextOriginationTime)
            addIfPresent(to: bext, .bextTimeReferenceLow, bextTimeReferenceLow)
            addIfPresent(to: bext, .bextTimeReferenceHigh, bextTimeReferenceHigh)
            addIfPresent(to: bext, .bextCodingHistory, bextCodingHistory)
            addIfPresent(to: bext, .bextUMID, bextUMID)
        }

        // HISTORY container
        if hasHistoryContent {
            let history = root.addChild(name: IXMLElement.history.rawValue)
            addIfPresent(to: history, .originalFilename, originalFilename)
            addIfPresent(to: history, .parentFilename, parentFilename)
            addIfPresent(to: history, .parentUID, parentUID)
        }

        // USER container — write raw content back if present
        if let userContent, let userDoc = try? AEXMLDocument(xml: userContent) {
            root.addChild(userDoc.root)
        }

        // STEINBERG container — write raw content back if present
        if let steinbergContent, let steinbergDoc = try? AEXMLDocument(xml: steinbergContent) {
            root.addChild(steinbergDoc.root)
        }

        // ASWG container — write raw content back if present
        if let aswgContent, let aswgDoc = try? AEXMLDocument(xml: aswgContent) {
            root.addChild(aswgDoc.root)
        }

        // LOCATION container
        if hasLocationContent {
            let loc = root.addChild(name: IXMLElement.location.rawValue)
            addIfPresent(to: loc, .locationGPS, locationGPS)
            addIfPresent(to: loc, .locationAltitude, locationAltitude)
            addIfPresent(to: loc, .locationTime, locationTime)
        }

        return doc.xml
    }

    private func addIfPresent(to parent: AEXMLElement, _ key: IXMLElement, _ value: String?) {
        guard let value, !value.isEmpty else { return }
        parent.addChild(name: key.rawValue, value: value)
    }

    /// Two decimal places.
    private func addIfPresent(to parent: AEXMLElement, _ key: IXMLElement, _ value: Double?) {
        guard let value else { return }
        parent.addChild(name: key.rawValue, value: String(format: "%.2f", value))
    }

    private var hasSpeedContent: Bool {
        masterSpeed != nil || currentSpeed != nil || timecodeRate != nil ||
            timecodeFlag != nil || fileSampleRate != nil || audioBitDepth != nil ||
            digitizerSampleRate != nil || timestampSamplesSinceMidnightHi != nil ||
            timestampSamplesSinceMidnightLo != nil || timestampSampleRate != nil
    }

    private var hasBextContent: Bool {
        bextVersion != nil || bextDescriptionText != nil || bextOriginator != nil ||
            bextOriginatorReference != nil || bextOriginationDate != nil ||
            bextOriginationTime != nil || bextTimeReferenceLow != nil ||
            bextTimeReferenceHigh != nil || bextCodingHistory != nil || bextUMID != nil
    }

    private var hasHistoryContent: Bool {
        originalFilename != nil || parentFilename != nil || parentUID != nil
    }

    private var hasLocationContent: Bool {
        locationGPS != nil || locationAltitude != nil || locationTime != nil
    }
}
