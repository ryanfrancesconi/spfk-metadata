// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import ImageIO
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

#if os(macOS)
    import SPFKFileSystem
#endif

/// One way the app saves a file. Each edits a description parsed from the prepared fixture; a
/// sequence saves twice from the same description, as ShadowTag does without reparsing.
enum SaveKind: String, CaseIterable, Hashable, Sendable, CustomTestStringConvertible {
    case k0 = "K0"
    case k1 = "K1"
    case k2 = "K2"
    case k3 = "K3"
    case k4 = "K4"
    case k5 = "K5"
    case k6 = "K6"
    case k7 = "K7"
    case k8 = "K8"
    case k9 = "K9"
    case k10 = "K10"
    case k11 = "K11"
    case k12 = "K12"
    case k13 = "K13"
    case k14 = "K14"
    case k15 = "K15"
    case k16 = "K16"
    case k17 = "K17"
    case s1 = "S1"
    case s2 = "S2"
    case s3 = "S3"
    case s4 = "S4"
    // The lower writers other callers use, each called as its consumer calls it.
    /// `TagProperties(url:)` then `save(to:)`, unedited (TorchTag).
    case e1 = "E1"
    /// As E1 with the title edited.
    case e2 = "E2"
    /// `TagPicture.write(_:path:)` with a picture (conversion, ShadowTag's import).
    case e3 = "E3"
    /// `TagPicture.write(nil, path:)` (conversion).
    case e4 = "E4"
    /// The marker utility conversion's `writeMarkers` dispatches to.
    case e5 = "E5"
    /// `ProductionChunks.writeBEXT` on a WAV (conversion).
    case e6 = "E6"
    /// `ProductionChunks.writeIXML` on a WAV (conversion).
    case e7 = "E7"
    /// `ProductionChunks.writeBEXT` on a FLAC (conversion).
    case e8 = "E8"
    /// `ProductionChunks.writeIXML` on a FLAC (conversion).
    case e9 = "E9"

    var testDescription: String { rawValue }

    /// One `save(dirtyFlags:storedXMPPacket:)` call and the edit made before it.
    struct Step {
        let flags: Set<MetadataDirtyFlag>
        var packet: StoredXMPPacketWrite = .keep
        let edit: (inout MetaAudioFileDescription) throws -> Void
    }

    /// The components the kind changes. Every other component the row holds must be unchanged.
    var written: Set<SafetyNetComponent> {
        switch self {
        case .k0, .k14, .e1: []
        case .k1, .e2: [.tags]
        case .k2: [.rating]
        case .k3, .e6, .e8: [.bext]
        case .k4, .e7, .e9: [.iXML]
        case .k5, .k6, .e3, .e4: [.artwork]
        case .k7, .k8, .e5: [.markers]
        case .k9: [.tags, .artwork]
        case .k10, .s3: [.tags, .markers]
        case .k11: [.artwork, .markers]
        case .k12: [.tags, .artwork, .markers]
        case .s4: [.packet, .tags]
        case .k13: [.finderTags]
        case .k15, .k17: [.packet]
        case .k16: [.packet, .tags]
        case .s1: [.markers, .tags]
        case .s2: [.artwork, .tags]
        }
    }

    /// Whether the save may touch the container at all. When not, the whole file must be
    /// byte-identical afterwards.
    var writesContainer: Bool {
        switch self {
        case .k13, .k14: false
        default: true
        }
    }

    /// Whether the kind leaves the file without artwork.
    var removesArtwork: Bool {
        self == .k6 || self == .e4
    }

    /// Whether the kind leaves the file without markers.
    var removesMarkers: Bool {
        self == .k8
    }

    /// Whether the kind runs a marker write, with or without an edit.
    func writesMarkers(for row: SafetyNetRow) -> Bool {
        self == .e5 || steps(for: row).contains { $0.flags.contains(.markers) }
    }

    func applies(to row: SafetyNetRow) -> Bool {
        switch self {
        case .k3: row.holds(.bext)
        case .k4: row.holds(.iXML)
        case .e6, .e7: row.holds(.bext) && row.fileType == .wav
        case .e8, .e9: row.holds(.bext) && row.fileType == .flac
        case .k7, .k8, .k10, .k11, .k12, .s1, .s3, .e5: row.holds(.markers)
        case .s4: row.holds(.packet)
        case .k13: row.holds(.finderTags)
        case .k15, .k16, .k17: row.holds(.packet)
        default: true
        }
    }

    func steps(for row: SafetyNetRow) -> [Step] {
        switch self {
        case .k0:
            let flags: Set<MetadataDirtyFlag> = row.holds(.markers) ? [.metadata, .image, .markers] : [.metadata, .image]
            return [Step(flags: flags) { _ in }]

        case .k1:
            return [Self.editTitle]

        case .k2:
            return [Step(flags: [.metadata]) { $0.tagProperties[.rating] = SafetyNetEdit.rating }]

        case .k3:
            return [Step(flags: [.metadata]) {
                var bext = try #require($0.bextDescription)
                bext.sequenceDescription = SafetyNetEdit.bextSequenceDescription
                $0.bextDescription = bext
            }]

        case .k4:
            return [Step(flags: [.metadata]) {
                let iXML = try #require($0.iXMLMetadata)
                try #require(iXML.contains(SafetyNetSetup.iXMLProject))
                $0.iXMLMetadata = iXML.replacingOccurrences(of: SafetyNetSetup.iXMLProject, with: SafetyNetEdit.iXMLProject)
            }]

        case .k5:
            return [Self.replaceArtwork]

        case .k6:
            return [Step(flags: [.image]) { $0.imageDescription.cgImage = nil }]

        case .k7:
            return [Self.replaceMarkers]

        case .k8:
            return [Step(flags: [.markers]) { $0.markerCollection = AudioMarkerDescriptionCollection() }]

        case .k13:
            return [Step(flags: [.finderTags]) { description in
                #if os(macOS)
                    description.urlProperties.finderTags = FinderTagGroup(tags: [FinderTagDescription(label: SafetyNetEdit.finderTag)])
                #endif
            }]

        case .k14:
            return [Step(flags: [.xmp]) { _ in }]

        case .k15:
            return [Step(flags: [], packet: .replace(SafetyNetEdit.packet)) { _ in }]

        case .k16:
            var step = Self.editTitle
            step.packet = .replace(SafetyNetEdit.packet)
            return [step]

        case .k17:
            return [Step(flags: [], packet: .remove) { _ in }]

        case .s1:
            return [Self.replaceMarkers, Self.editTitle]

        case .k9:
            return [Self.combined([.metadata, .image])]

        case .k10:
            return [Self.combined([.metadata, .markers])]

        case .k11:
            return [Self.combined([.image, .markers])]

        case .k12:
            return [Self.combined([.metadata, .image, .markers])]

        case .s3:
            return [Self.editTitle, Self.replaceMarkers]

        case .s4:
            return [Step(flags: [], packet: .replace(SafetyNetEdit.packet)) { _ in }, Self.editTitle]

        case .s2:
            return [Self.replaceArtwork, Self.editTitle]

        case .e1, .e2, .e3, .e4, .e5, .e6, .e7, .e8, .e9:
            return []
        }
    }

    /// Runs every step on one description, in order; an entry-point kind writes the file the
    /// description was parsed from instead.
    func run(on description: inout MetaAudioFileDescription, row: SafetyNetRow) throws {
        if try runEntryPoint(on: description, row: row) { return }

        for step in steps(for: row) {
            try step.edit(&description)
            try description.save(dirtyFlags: step.flags, storedXMPPacket: step.packet)
        }
    }

    /// One save carrying several flags, each with the edit its single-flag kind makes.
    private static func combined(_ flags: Set<MetadataDirtyFlag>) -> Step {
        let steps = [(MetadataDirtyFlag.metadata, editTitle), (.image, replaceArtwork), (.markers, replaceMarkers)]
            .filter { flags.contains($0.0) }.map(\.1)

        return Step(flags: flags) { description in
            for step in steps {
                try step.edit(&description)
            }
        }
    }

    private static var editTitle: Step {
        Step(flags: [.metadata]) {
            $0.tagProperties[.title] = SafetyNetEdit.title
            $0.tagProperties.data.set(customTag: SafetyNetSetup.customTagKey, value: SafetyNetEdit.customTagValue)
        }
    }

    private static var replaceArtwork: Step {
        Step(flags: [.image]) {
            $0.imageDescription.pictureRef = try SafetyNetSetup.picture(TestBundleResources.shared.songbird)
        }
    }

    private static var replaceMarkers: Step {
        Step(flags: [.markers]) {
            $0.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: SafetyNetEdit.markers)
        }
    }
}

/// What the save kinds write; each differs from its ``SafetyNetSetup`` counterpart.
enum SafetyNetEdit {
    static let title = "Safety Net Edited"
    static let customTagValue = "Edited"
    static let rating = "2"
    static let bextSequenceDescription = "Safety Net BEXT Edited"
    static let iXMLProject = "Safety Net Project Edited"
    static let markers = [
        AudioMarkerDescription(name: "Edit One", startTime: 0.2),
        AudioMarkerDescription(name: "Edit Two", startTime: 0.4),
    ]
    static let packet = SafetyNetSetup.xmpPacket(title: "Edited")
    static let finderTag = "Safety Net Edited"

    /// Windows Media Player's `POPM` byte for ``rating``'s two stars.
    static let popmRating: UInt8 = 64

    /// The pixel size of the artwork ``SaveKind/k5`` writes, as ImageIO reads the source file.
    static func artworkPixelSize() throws -> String {
        try SafetyNetImage.pixelSize(of: Data(contentsOf: TestBundleResources.shared.songbird))
    }
}

/// Image facts read through ImageIO, which shares no code with the writers under test.
enum SafetyNetImage {
    struct UndecodableImage: Error {}

    /// `"<width>x<height>"`.
    static func pixelSize(of data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw UndecodableImage() }

        return "\(width)x\(height)"
    }
}
