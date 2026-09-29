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
    /// Parsed fields are available via ``userFields``. UCS fields via ``ucsFields``.
    public var userContent: String?

    // MARK: - ASWG Container

    /// Raw XML content of the ASWG container, preserved as a string.
    /// Parsed fields are available via ``aswgFields``.
    public var aswgContent: String?

    // MARK: - STEINBERG Container

    /// Raw XML content of the STEINBERG container, preserved as a string.
    public var steinbergContent: String?

    // MARK: - LOCATION Container

    /// GPS coordinates string from the LOCATION container.
    public var locationGPS: String?

    /// Altitude string from the LOCATION container.
    public var locationAltitude: String?

    /// Time string from the LOCATION container.
    public var locationTime: String?

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

        // ASWG container — preserve raw content
        if let aswg = root[.aswg], aswg.children.isNotEmpty {
            aswgContent = aswg.xml
        }

        // STEINBERG container — preserve raw content
        if let steinberg = root[.steinberg], steinberg.children.isNotEmpty {
            steinbergContent = steinberg.xml
        }

        // LOCATION container
        if let location = root[.location] {
            locationGPS = location[.locationGPS]?.value
            locationAltitude = location[.locationAltitude]?.value
            locationTime = location[.locationTime]?.value
        }
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

}
