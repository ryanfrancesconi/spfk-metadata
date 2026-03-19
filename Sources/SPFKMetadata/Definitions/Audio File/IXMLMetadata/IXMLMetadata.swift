// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

@preconcurrency import AEXML
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase

/// A structured representation of iXML (BWFXML) chunk metadata for WAV files.
///
/// Supports both parsing existing iXML content and creating new iXML documents
/// from structured properties. Follows the iXML specification at
/// http://www.gallery.co.uk/ixml/
///
/// The iXML chunk is used by professional audio applications (Pro Tools, Sound Devices,
/// Steinberg, etc.) to store extended production metadata inside WAV files.
///
/// **Parse:** Use ``init(xml:)`` to create from an XML string.
///
/// **Create:** Set properties directly and call ``xml`` to generate the XML string.
///
/// All properties are optional. Unknown elements in parsed XML are preserved in the
/// underlying document for round-trip fidelity.
public struct IXMLMetadata: Equatable, Sendable {
    public static func == (lhs: IXMLMetadata, rhs: IXMLMetadata) -> Bool {
        lhs.xml == rhs.xml
    }

    /// The underlying AEXML document. Preserved for round-trip fidelity of
    /// elements not explicitly modeled as properties.
    public private(set) var document: AEXMLDocument

    // MARK: - Top-Level Properties

    /// iXML specification version (e.g., "1.52").
    public var version: String?

    /// Production project name.
    public var project: String?

    /// Scene identifier.
    public var scene: String?

    /// Take number or identifier.
    public var take: String?

    /// Tape/reel identifier.
    public var tape: String?

    /// Unique family identifier (groups related files from the same recording).
    public var familyUID: String?

    /// Family name (human-readable group name).
    public var familyName: String?

    /// Unique file identifier.
    public var fileUID: String?

    /// Free-form note or comment about the recording.
    public var note: String?

    /// Whether the take was circled (selected as a good take). `"TRUE"` or `"FALSE"`.
    public var circled: String?

    /// Whether the recording is a wild track (not synced to picture). `"TRUE"` or `"FALSE"`.
    public var wildTrack: String?

    // MARK: - SPEED Container

    /// Master speed (e.g., "23.976" for film).
    public var masterSpeed: String?

    /// Current playback speed.
    public var currentSpeed: String?

    /// Timecode rate (e.g., "24", "25", "2997ND", "2997DF", "30").
    public var timecodeRate: String?

    /// Timecode flag (e.g., "NDF" for non-drop, "DF" for drop frame).
    public var timecodeFlag: String?

    /// File sample rate in Hz (e.g., "48000").
    public var fileSampleRate: String?

    /// Audio bit depth (e.g., "24").
    public var audioBitDepth: String?

    /// Digitizer sample rate in Hz.
    public var digitizerSampleRate: String?

    /// Timestamp high word (samples since midnight).
    public var timestampSamplesSinceMidnightHi: String?

    /// Timestamp low word (samples since midnight).
    public var timestampSamplesSinceMidnightLo: String?

    /// Timestamp sample rate.
    public var timestampSampleRate: String?

    // MARK: - TRACK_LIST Container

    /// Parsed track entries from the TRACK_LIST container.
    public var tracks: [Track]?

    // MARK: - LOUDNESS Container

    /// Loudness metrics parsed from or to be written to the LOUDNESS container.
    public var loudnessDescription: LoudnessDescription?

    // MARK: - BEXT Container

    /// BEXT fields mirrored in the iXML BEXT container.
    public var bextVersion: String?
    public var bextDescriptionText: String?
    public var bextOriginator: String?
    public var bextOriginatorReference: String?
    public var bextOriginationDate: String?
    public var bextOriginationTime: String?
    public var bextTimeReferenceLow: String?
    public var bextTimeReferenceHigh: String?
    public var bextCodingHistory: String?
    public var bextUMID: String?

    // MARK: - HISTORY Container

    /// Original filename from the HISTORY container.
    public var originalFilename: String?

    /// Parent filename from the HISTORY container.
    public var parentFilename: String?

    /// Parent file UID from the HISTORY container.
    public var parentUID: String?

    // MARK: - USER Container

    /// Raw XML content of the USER container, preserved as a string.
    /// Vendor-specific data (ASWG, Steinberg, etc.) lives here.
    public var userContent: String?

    // MARK: - Initialization

    /// Creates an empty `IXMLMetadata` with a default BWFXML document shell.
    public init() {
        document = AEXMLDocument()
        document.addChild(name: IXMLElement.bwfxml.rawValue)
    }

    /// Creates an `IXMLMetadata` by parsing an XML string.
    ///
    /// - Parameter xml: A valid iXML string (typically from a WAV file's iXML chunk).
    /// - Throws: If the string is not well-formed XML.
    public init(xml: String) throws {
        let doc = try AEXMLDocument(xml: xml)
        self.init(document: doc)
    }

    /// All initializers resolve here.
    ///
    /// Creates an `IXMLMetadata` by parsing an `AEXMLDocument`.
    ///
    /// - Parameter doc: An `AEXMLDocument` with a `<BWFXML>` root element.
    public init(document doc: AEXMLDocument) {
        document = doc

        guard let root = doc.root[.bwfxml] ?? nonErrorRoot(doc) else {
            Log.error("Failed to find BWFXML root element")
            return
        }

        // Top-level elements
        version = root[.ixmlVersion]?.value
        project = root[.project]?.value
        scene = root[.scene]?.value
        take = root[.take]?.value
        tape = root[.tape]?.value
        familyUID = root[.familyUID]?.value
        familyName = root[.familyName]?.value
        fileUID = root[.fileUID]?.value
        note = root[.note]?.value
        circled = root[.circled]?.value
        wildTrack = root[.wildTrack]?.value

        // SPEED container
        if let speed = root[.speed] {
            masterSpeed = speed[.masterSpeed]?.value
            currentSpeed = speed[.currentSpeed]?.value
            timecodeRate = speed[.timecodeRate]?.value
            timecodeFlag = speed[.timecodeFlag]?.value
            fileSampleRate = speed[.fileSampleRate]?.value
            audioBitDepth = speed[.audioBitDepth]?.value
            digitizerSampleRate = speed[.digitizerSampleRate]?.value
            timestampSamplesSinceMidnightHi = speed[.timestampSamplesSinceMidnightHi]?.value
            timestampSamplesSinceMidnightLo = speed[.timestampSamplesSinceMidnightLo]?.value
            timestampSampleRate = speed[.timestampSampleRate]?.value
        }

        // TRACK_LIST container
        if let trackList = root[.trackList] {
            tracks = parseTracks(trackList: trackList)
        }

        // LOUDNESS container
        if let loudness = root[.loudness] {
            loudnessDescription = parseLoudness(element: loudness)
        }

        // BEXT container
        if let bext = root[.bext] {
            bextVersion = bext[.bextVersion]?.value
            bextDescriptionText = bext[.bextDescription]?.value
            bextOriginator = bext[.bextOriginator]?.value
            bextOriginatorReference = bext[.bextOriginatorReference]?.value
            bextOriginationDate = bext[.bextOriginationDate]?.value
            bextOriginationTime = bext[.bextOriginationTime]?.value
            bextTimeReferenceLow = bext[.bextTimeReferenceLow]?.value
            bextTimeReferenceHigh = bext[.bextTimeReferenceHigh]?.value
            bextCodingHistory = bext[.bextCodingHistory]?.value
            bextUMID = bext[.bextUMID]?.value
        }

        // HISTORY container
        if let history = root[.history] {
            originalFilename = history[.originalFilename]?.value
            parentFilename = history[.parentFilename]?.value
            parentUID = history[.parentUID]?.value
        }

        // USER container — preserve raw content
        if let user = root[.user], user.children.isNotEmpty {
            userContent = user.xml
        }
    }

    // MARK: - XML Generation

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

            if let value = loudness.loudnessIntegrated {
                loudnessElement.addChild(
                    name: IXMLElement.loudnessValue.rawValue,
                    value: String(format: "%.2f", value)
                )
            }

            if let value = loudness.loudnessRange {
                loudnessElement.addChild(
                    name: IXMLElement.loudnessRange.rawValue,
                    value: String(format: "%.2f", value)
                )
            }

            if let value = loudness.maxTruePeakLevel {
                loudnessElement.addChild(
                    name: IXMLElement.maxTruePeakLevel.rawValue,
                    value: String(format: "%.2f", value)
                )
            }

            if let value = loudness.maxMomentaryLoudness {
                loudnessElement.addChild(
                    name: IXMLElement.maxMomentary.rawValue,
                    value: String(format: "%.2f", value)
                )
            }

            if let value = loudness.maxShortTermLoudness {
                loudnessElement.addChild(
                    name: IXMLElement.maxShortTerm.rawValue,
                    value: String(format: "%.2f", value)
                )
            }
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

        return doc.xml
    }
}

// MARK: - Track

extension IXMLMetadata {
    /// A single track entry from the iXML TRACK_LIST container.
    public struct Track: Equatable, Sendable {
        /// 1-based channel index in the file.
        public var channelIndex: String?

        /// Interleave index for multi-channel files.
        public var interleaveIndex: String?

        /// Track name (e.g., "Boom", "Lav 1").
        public var name: String?

        /// Track function (e.g., "INPUT", "MIX").
        public var function: String?

        public init(
            channelIndex: String? = nil,
            interleaveIndex: String? = nil,
            name: String? = nil,
            function: String? = nil
        ) {
            self.channelIndex = channelIndex
            self.interleaveIndex = interleaveIndex
            self.name = name
            self.function = function
        }
    }
}

// MARK: - Creation from MetaAudioFileDescription

extension IXMLMetadata {
    /// Creates an iXML document populated from the given metadata description.
    ///
    /// Maps available properties from the audio format, BEXT description, tags,
    /// and loudness data into the corresponding iXML elements.
    ///
    /// - Parameter description: The metadata to populate from.
    public init(from description: MetaAudioFileDescription) {
        self.init()

        version = "1.52"
        project = description.tag(for: .album)
        note = description.tag(for: .comment)

        // SPEED from audio format
        if let format = description.audioFormat {
            fileSampleRate = "\(Int(format.sampleRate))"

            if let bits = format.bitsPerChannel {
                audioBitDepth = "\(bits)"
            }

            // Build track list from channel count
            if format.channelCount > 0 {
                var trackEntries = [Track]()
                for i in 1 ... Int(format.channelCount) {
                    trackEntries.append(Track(
                        channelIndex: "\(i)",
                        interleaveIndex: "\(i)"
                    ))
                }
                tracks = trackEntries
            }
        }

        // BEXT container from BEXTDescription
        if let bext = description.bextDescription {
            bextVersion = "\(bext.version)"
            bextDescriptionText = bext.sequenceDescription
            bextOriginator = bext.originator
            bextOriginatorReference = bext.originatorReference
            bextOriginationDate = bext.originationDate
            bextOriginationTime = bext.originationTime

            if let value = bext.timeReferenceLow {
                bextTimeReferenceLow = "\(value)"
            }
            if let value = bext.timeReferenceHigh {
                bextTimeReferenceHigh = "\(value)"
            }

            bextCodingHistory = bext.codingHistory
            bextUMID = bext.umid

            // LOUDNESS from BEXT v2
            let loudness = bext.loudnessDescription.validated()
            if loudness.isValid {
                loudnessDescription = loudness
            }
        }

        // Original filename from URL
        originalFilename = description.url.lastPathComponent
    }
}

// MARK: - Private Helpers

extension IXMLMetadata {
    /// AEXML's `doc.root` returns the first child, but if the root IS BWFXML
    /// we need to handle both cases.
    private func nonErrorRoot(_ doc: AEXMLDocument) -> AEXMLElement? {
        let root = doc.root
        guard root.error == nil, root.name == IXMLElement.bwfxml.rawValue else {
            return nil
        }
        return root
    }

    private func parseTracks(trackList: AEXMLElement) -> [Track]? {
        guard let trackElements = trackList[.track]?.all else { return nil }

        var result = [Track]()

        for element in trackElements {
            let track = Track(
                channelIndex: element[.channelIndex]?.value,
                interleaveIndex: element[.interleaveIndex]?.value,
                name: element[.name]?.value,
                function: element[.function]?.value
            )
            result.append(track)
        }

        return result.isEmpty ? nil : result
    }

    private func parseLoudness(element: AEXMLElement) -> LoudnessDescription? {
        let integrated = element[.loudnessValue]?.value.flatMap { Float64($0) }
        let range = element[.loudnessRange]?.value.flatMap { Float64($0) }
        let truePeak = element[.maxTruePeakLevel]?.value.flatMap { Float32($0) }
        let momentary = element[.maxMomentary]?.value.flatMap { Float64($0) }
        let shortTerm = element[.maxShortTerm]?.value.flatMap { Float64($0) }

        let desc = LoudnessDescription(
            loudnessIntegrated: integrated,
            loudnessRange: range,
            maxTruePeakLevel: truePeak,
            maxMomentaryLoudness: momentary,
            maxShortTermLoudness: shortTerm
        )

        return desc.isValid ? desc : nil
    }

    private func addIfPresent(to parent: AEXMLElement, _ key: IXMLElement, _ value: String?) {
        guard let value, !value.isEmpty else { return }
        parent.addChild(name: key.rawValue, value: value)
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
}
