// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

@preconcurrency import AEXML
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase

/// iXML (BWFXML) chunk metadata, per http://www.gallery.co.uk/ixml/. Parse with ``init(xml:)``;
/// ``xml`` writes the modeled properties back into the parsed document.
public struct IXMLMetadata: Equatable, Sendable {
    public static func == (lhs: IXMLMetadata, rhs: IXMLMetadata) -> Bool {
        lhs.xml == rhs.xml
    }

    /// The document parsed from, never mutated; ``xml`` edits a copy so unmodeled elements survive.
    public private(set) var document: AEXMLDocument

    // MARK: - Top-Level Properties

    /// iXML specification version (e.g., "1.52").
    public var version: String?

    public var project: String?

    public var scene: String?

    public var take: String?

    public var tape: String?

    /// Unique family identifier (groups related files from the same recording).
    public var familyUID: String?

    /// Family name (human-readable group name).
    public var familyName: String?

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

    public var currentSpeed: String?

    /// Timecode rate (e.g., "24", "25", "2997ND", "2997DF", "30").
    public var timecodeRate: String?

    /// Timecode flag (e.g., "NDF" for non-drop, "DF" for drop frame).
    public var timecodeFlag: String?

    /// File sample rate in Hz (e.g., "48000").
    public var fileSampleRate: String?

    /// Audio bit depth (e.g., "24").
    public var audioBitDepth: String?

    public var digitizerSampleRate: String?

    /// Timestamp high word (samples since midnight).
    public var timestampSamplesSinceMidnightHi: String?

    /// Timestamp low word (samples since midnight).
    public var timestampSamplesSinceMidnightLo: String?

    public var timestampSampleRate: String?

    // MARK: - TRACK_LIST Container

    public var tracks: [Track]?

    // MARK: - LOUDNESS Container

    public var loudnessDescription: LoudnessDescription?

    // MARK: - BEXT Container

    /// The BEXT chunk's fields, as mirrored in iXML.
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

    public var originalFilename: String?

    public var parentFilename: String?

    public var parentUID: String?

    // MARK: - USER Container

    /// The container's raw XML; ``userFields`` and ``ucsFields`` parse it.
    public var userContent: String?

    // MARK: - ASWG Container

    /// The container's raw XML; ``aswgFields`` parses it.
    public var aswgContent: String?

    // MARK: - STEINBERG Container

    public var steinbergContent: String?

    // MARK: - LOCATION Container

    public var locationGPS: String?

    public var locationAltitude: String?

    public var locationTime: String?

    // MARK: - Initialization

    public init() {
        document = AEXMLDocument()
        document.addChild(name: IXMLElement.bwfxml.rawValue)
    }

    /// Throws when the string is not well-formed XML.
    public init(xml: String) throws {
        let doc = try Self.document(xml: xml)
        self.init(document: doc)
    }

    /// Parses without trimming, so every value keeps its text as read -- line breaks and edge
    /// spaces included -- through an edit of any other field.
    static func document(xml: String) throws -> AEXMLDocument {
        var options = AEXMLOptions()
        options.parserSettings.shouldTrimWhitespace = false
        return try AEXMLDocument(xml: xml, options: options)
    }

    /// All initializers resolve here. Expects a `<BWFXML>` root.
    public init(document doc: AEXMLDocument) {
        document = doc

        guard let root = doc.root[.bwfxml] ?? nonErrorRoot(doc) else {
            Log.error("Failed to find BWFXML root element")
            return
        }

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

        if let trackList = root[.trackList] {
            tracks = parseTracks(trackList: trackList)
        }

        if let loudness = root[.loudness] {
            loudnessDescription = parseLoudness(element: loudness)
        }

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

        if let history = root[.history] {
            originalFilename = history[.originalFilename]?.value
            parentFilename = history[.parentFilename]?.value
            parentUID = history[.parentUID]?.value
        }

        if let user = root[.user], user.children.isNotEmpty {
            userContent = user.xml
        }

        if let aswg = root[.aswg], aswg.children.isNotEmpty {
            aswgContent = aswg.xml
        }

        if let steinberg = root[.steinberg], steinberg.children.isNotEmpty {
            steinbergContent = steinberg.xml
        }

        if let location = root[.location] {
            locationGPS = location[.locationGPS]?.value
            locationAltitude = location[.locationAltitude]?.value
            locationTime = location[.locationTime]?.value
        }
    }
}

// MARK: - Private Helpers

extension IXMLMetadata {
    /// `doc.root` is the first child; this covers a document whose root is BWFXML itself.
    func nonErrorRoot(_ doc: AEXMLDocument) -> AEXMLElement? {
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
