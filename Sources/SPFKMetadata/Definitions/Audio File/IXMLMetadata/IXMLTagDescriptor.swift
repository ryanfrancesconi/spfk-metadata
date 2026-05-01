// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKMetadataBase

// swiftformat:disable consecutiveSpaces

// MARK: - IXMLSection

/// Grouping container for iXML fields, corresponding to top-level XML containers in the BWFXML schema.
public enum IXMLSection: String, Sendable, CaseIterable, Equatable {
    case core
    case user
    case aswg
    case bext
    case speed
    case history
    case location
    case loudness

    public var displayName: String {
        switch self {
        case .core:     "Core"
        case .user:     "User"
        case .aswg:     "ASWG"
        case .bext:     "BEXT"
        case .speed:    "Speed"
        case .history:  "History"
        case .location: "Location"
        case .loudness: "Loudness"
        }
    }

    /// Whether all fields in this section are read-only by policy.
    ///
    /// SPEED and LOUDNESS are auto-populated from audio format/analysis data.
    /// BEXT is managed by the dedicated BEXT editor tab.
    /// HISTORY is provenance data set by the recording device.
    public var isSectionReadOnly: Bool {
        switch self {
        case .speed, .loudness, .bext, .history:
            true
        case .core, .user, .aswg, .location:
            false
        }
    }
}

// MARK: - IXMLTagDescriptor

/// Describes a single field in the iXML (BWFXML) metadata schema.
///
/// Used by the iXML properties editor to render and edit structured iXML fields
/// without coupling the UI layer to the underlying XML structure.
/// Field values are accessed at runtime via ``IXMLMetadata/value(for:)`` and
/// ``IXMLMetadata/setValue(_:for:)``.
public struct IXMLTagDescriptor: Sendable, Equatable {
    /// Display name shown in the editor's label column.
    public let displayName: String

    /// The container section this field belongs to.
    public let section: IXMLSection

    /// The raw XML element name within its container (e.g. `"TRACKTITLE"`, `"songTitle"`).
    public let xmlTag: String

    /// Whether this field is display-only. Overrides ``section`` `isSectionReadOnly`.
    public let isReadOnly: Bool

    /// How the field value should be presented in the editor.
    public let editStyle: EditStyle

    /// Whether the field should use a tall multi-line text area rather than a single-line field.
    public let isMultiLine: Bool

    public enum EditStyle: Sendable, Equatable {
        case text
        case boolean    // "TRUE" / "FALSE"
        case numeric
        case date       // ISO 8601 date string
    }

    public init(
        displayName: String,
        section: IXMLSection,
        xmlTag: String,
        isReadOnly: Bool = false,
        editStyle: EditStyle = .text,
        isMultiLine: Bool = false
    ) {
        self.displayName = displayName
        self.section = section
        self.xmlTag = xmlTag
        self.isReadOnly = isReadOnly || section.isSectionReadOnly
        self.editStyle = editStyle
        self.isMultiLine = isMultiLine
    }
}

// MARK: - Identifier

extension IXMLTagDescriptor {
    /// Unique string combining section and XML tag name.
    ///
    /// Used as the `NSUserInterfaceItemIdentifier.rawValue` for `PropertiesGroupView` rows
    /// so that the editor can map a changed model back to its descriptor without name collisions
    /// across sections (e.g. both USER and ASWG have a "category" field).
    public var identifier: String {
        "\(section.rawValue).\(xmlTag)"
    }
}

// MARK: - Descriptor Lookup

extension IXMLTagDescriptor {
    /// Returns all descriptors for a given section, sorted by `displayName`.
    public static func descriptors(for section: IXMLSection) -> [IXMLTagDescriptor] {
        allDescriptors.filter { $0.section == section }.sorted { $0.displayName < $1.displayName }
    }

    /// Finds a descriptor by its stable identifier (`"section.xmlTag"`).
    public static func descriptor(forIdentifier id: String) -> IXMLTagDescriptor? {
        allDescriptors.first { $0.identifier == id }
    }
}

// MARK: - Descriptor Registry

extension IXMLTagDescriptor {
    /// Canonical ordered list of all iXML fields, grouped by section.
    ///
    /// Defines display order for the iXML editor. Read-only fields are shown
    /// without text entry controls. Sections with no data present at runtime
    /// can be hidden by the UI.
    public static let allDescriptors: [IXMLTagDescriptor] =
        coreDescriptors.sorted { $0.displayName < $1.displayName }
            + userDescriptors.sorted { $0.displayName < $1.displayName }
            + aswgDescriptors.sorted { $0.displayName < $1.displayName }
            + bextDescriptors.sorted { $0.displayName < $1.displayName }
            + speedDescriptors.sorted { $0.displayName < $1.displayName }
            + historyDescriptors.sorted { $0.displayName < $1.displayName }
            + locationDescriptors.sorted { $0.displayName < $1.displayName }
            + loudnessDescriptors.sorted { $0.displayName < $1.displayName }

    // MARK: - Core (BWFXML top-level)

    private static let coreDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: "Circled",       section: .core, xmlTag: "CIRCLED",          editStyle: .boolean),
        .init(displayName: "Family Name",   section: .core, xmlTag: "FAMILY_NAME"),
        .init(displayName: "Family UID",    section: .core, xmlTag: "FAMILY_UID",       isReadOnly: true),
        .init(displayName: "File UID",      section: .core, xmlTag: "FILE_UID",         isReadOnly: true),
        .init(displayName: "iXML Version",   section: .core, xmlTag: "IXML_VERSION",    isReadOnly: true),
        .init(displayName: "Note",          section: .core, xmlTag: "NOTE",             isMultiLine: true),
        .init(displayName: "Project",       section: .core, xmlTag: "PROJECT"),
        .init(displayName: "Scene",         section: .core, xmlTag: "SCENE"),
        .init(displayName: "Take",          section: .core, xmlTag: "TAKE"),
        .init(displayName: "Tape",          section: .core, xmlTag: "TAPE"),
        .init(displayName: "Wild Track",    section: .core, xmlTag: "WILD_TRACK",       editStyle: .boolean),
    ]

    // MARK: - USER (Soundminer / de facto library standard)

    private static let userDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: "Artist",          section: .user, xmlTag: "ARTIST"),
        .init(displayName: "BPM",             section: .user, xmlTag: "BPM",            editStyle: .numeric),
        .init(displayName: "Cat ID",          section: .user, xmlTag: "CATID"),
        .init(displayName: "Category Full",   section: .user, xmlTag: "CATEGORYFULL"),
        .init(displayName: "Category",        section: .user, xmlTag: "CATEGORY"),
        .init(displayName: "CD Title",        section: .user, xmlTag: "CDTITLE"),
        .init(displayName: "Composer",        section: .user, xmlTag: "COMPOSER"),
        .init(displayName: "Description",     section: .user, xmlTag: "DESCRIPTION",    isMultiLine: true),
        .init(displayName: "Designer",        section: .user, xmlTag: "DESIGNER"),
        .init(displayName: "Embedder",        section: .user, xmlTag: "EMBEDDER",       isReadOnly: true),
        .init(displayName: "FX Name",         section: .user, xmlTag: "FXNAME"),
        .init(displayName: "Keywords",        section: .user, xmlTag: "KEYWORDS",       isMultiLine: true),
        .init(displayName: "Library",         section: .user, xmlTag: "LIBRARY"),
        .init(displayName: "Location",        section: .user, xmlTag: "LOCATION"),
        .init(displayName: "Long ID",         section: .user, xmlTag: "LONGID"),
        .init(displayName: "Manufacturer",    section: .user, xmlTag: "MANUFACTURER"),
        .init(displayName: "Mic Perspective", section: .user, xmlTag: "MICPERSPECTIVE"),
        .init(displayName: "Microphone",      section: .user, xmlTag: "MICROPHONE"),
        .init(displayName: "Notes",           section: .user, xmlTag: "NOTES",          isMultiLine: true),
        .init(displayName: "Open Tier",       section: .user, xmlTag: "OPENTIER"),
        .init(displayName: "Publisher",       section: .user, xmlTag: "PUBLISHER"),
        .init(displayName: "Rating",          section: .user, xmlTag: "RATING"),
        .init(displayName: "Rec Medium",      section: .user, xmlTag: "RECMEDIUM"),
        .init(displayName: "Rec Type",        section: .user, xmlTag: "RECTYPE"),
        .init(displayName: "Release Date",    section: .user, xmlTag: "RELEASEDATE",    editStyle: .date),
        .init(displayName: "Shoot Date",      section: .user, xmlTag: "SHOOTDATE",      editStyle: .date),
        .init(displayName: "Short ID",        section: .user, xmlTag: "SHORTID"),
        .init(displayName: "Show",            section: .user, xmlTag: "SHOW"),
        .init(displayName: "Source",          section: .user, xmlTag: "SOURCE"),
        .init(displayName: "Subcategory",     section: .user, xmlTag: "SUBCATEGORY"),
        .init(displayName: "Track Title",     section: .user, xmlTag: "TRACKTITLE"),
        .init(displayName: "Track Year",      section: .user, xmlTag: "TRACKYEAR",      editStyle: .numeric),
        .init(displayName: "Track",           section: .user, xmlTag: "TRACK",          editStyle: .numeric),
        .init(displayName: "URL",             section: .user, xmlTag: "URL"),
        .init(displayName: "User Category",   section: .user, xmlTag: "USERCATEGORY"),
        .init(displayName: "User Comments",   section: .user, xmlTag: "USERCOMMENTS",   isMultiLine: true),
        .init(displayName: "Vendor Category", section: .user, xmlTag: "VENDORCATEGORY"),
        .init(displayName: "Volume",          section: .user, xmlTag: "VOLUME"),
    ]

    // MARK: - ASWG (Audio Services Working Group)

    private static let aswgDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: "Cat ID",          section: .aswg, xmlTag: "catId"),
        .init(displayName: "Category",        section: .aswg, xmlTag: "category"),
        .init(displayName: "Composer",        section: .aswg, xmlTag: "composer"),
        .init(displayName: "Key",             section: .aswg, xmlTag: "inKey"),
        .init(displayName: "Library",         section: .aswg, xmlTag: "library"),
        .init(displayName: "Mic Type",        section: .aswg, xmlTag: "micType"),
        .init(displayName: "Music Publisher", section: .aswg, xmlTag: "musicPublisher"),
        .init(displayName: "Notes",           section: .aswg, xmlTag: "notes",          isMultiLine: true),
        .init(displayName: "Originator",      section: .aswg, xmlTag: "originator"),
        .init(displayName: "Song Title",      section: .aswg, xmlTag: "songTitle"),
        .init(displayName: "Subcategory",     section: .aswg, xmlTag: "subCategory"),
        .init(displayName: "Tempo",           section: .aswg, xmlTag: "tempo",          editStyle: .numeric),
        .init(displayName: "User Category",   section: .aswg, xmlTag: "userCategory"),
        .init(displayName: TagKey.isrc.displayName, section: .aswg, xmlTag: "isrcId"),
    ]

    // MARK: - BEXT (read-only mirror of binary BEXT chunk; managed by the BEXT editor tab)

    private static let bextDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: "BWF Coding History",       section: .bext, xmlTag: "BWF_CODING_HISTORY",      isMultiLine: true),
        .init(displayName: "BWF Description",          section: .bext, xmlTag: "BWF_DESCRIPTION",         isMultiLine: true),
        .init(displayName: "BWF Origination Date",     section: .bext, xmlTag: "BWF_ORIGINATION_DATE"),
        .init(displayName: "BWF Origination Time",     section: .bext, xmlTag: "BWF_ORIGINATION_TIME"),
        .init(displayName: "BWF Originator Reference", section: .bext, xmlTag: "BWF_ORIGINATOR_REFERENCE"),
        .init(displayName: "BWF Originator",           section: .bext, xmlTag: "BWF_ORIGINATOR"),
        .init(displayName: "BWF UMID",                 section: .bext, xmlTag: "BWF_UMID"),
        .init(displayName: "BWF Version",              section: .bext, xmlTag: "BWF_VERSION"),
    ]

    // MARK: - SPEED (read-only; auto-populated from audio format)

    private static let speedDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: "Bit Depth",     section: .speed, xmlTag: "AUDIO_BIT_DEPTH",   editStyle: .numeric),
        .init(displayName: "Current Speed", section: .speed, xmlTag: "CURRENT_SPEED"),
        .init(displayName: "Master Speed",  section: .speed, xmlTag: "MASTER_SPEED"),
        .init(displayName: "Sample Rate",   section: .speed, xmlTag: "FILE_SAMPLE_RATE",  editStyle: .numeric),
        .init(displayName: "Timecode Flag",       section: .speed, xmlTag: "TIMECODE_FLAG"),
        .init(displayName: "Timecode Rate",       section: .speed, xmlTag: "TIMECODE_RATE"),
    ]

    // MARK: - HISTORY (read-only; provenance data from recording device)

    private static let historyDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: "Original Filename", section: .history, xmlTag: "ORIGINAL_FILENAME"),
        .init(displayName: "Parent Filename",   section: .history, xmlTag: "PARENT_FILENAME"),
        .init(displayName: "Parent UID",        section: .history, xmlTag: "PARENT_UID"),
    ]

    // MARK: - LOCATION

    private static let locationDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: "Altitude", section: .location, xmlTag: "ALTITUDE"),
        .init(displayName: "GPS",      section: .location, xmlTag: "GPS"),
        .init(displayName: "Time",     section: .location, xmlTag: "TIME"),
    ]

    // MARK: - LOUDNESS (read-only; from EBU R128 analysis)

    private static let loudnessDescriptors: [IXMLTagDescriptor] = [
        .init(displayName: TagKey.loudnessIntegrated.displayName,   section: .loudness, xmlTag: "LOUDNESS_VALUE",      editStyle: .numeric),
        .init(displayName: TagKey.loudnessMaxMomentary.displayName, section: .loudness, xmlTag: "MAX_MOMENTARY",       editStyle: .numeric),
        .init(displayName: TagKey.loudnessMaxShortTerm.displayName, section: .loudness, xmlTag: "MAX_SHORT_TERM",      editStyle: .numeric),
        .init(displayName: TagKey.loudnessRange.displayName,        section: .loudness, xmlTag: "LOUDNESS_RANGE",      editStyle: .numeric),
        .init(displayName: TagKey.loudnessTruePeak.displayName,     section: .loudness, xmlTag: "MAX_TRUE_PEAK_LEVEL", editStyle: .numeric),
    ]
}

// swiftformat:enable consecutiveSpaces
