// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

#if os(macOS)
    import SPFKFileSystem
#endif

/// A component the app owns and writes. Everything else in the file is foreign.
enum SafetyNetComponent: String, CaseIterable, Hashable, Sendable {
    case tags, rating, artwork, markers, bext, iXML, packet, finderTags
}

/// Data another app put in the file, and how the fixture plants it after the setup save.
struct SafetyNetForeignItem: Sendable {
    let item: SafetyNetItem
    let inject: @Sendable (URL) throws -> Void

    /// An xattr no writer of ours knows about. Lost by any save that replaces the file.
    /// An item the row's ``SafetyNetRow/plant`` step puts in place.
    init(item: SafetyNetItem) {
        self.init(item: item) { _ in }
    }

    init(item: SafetyNetItem, inject: @escaping @Sendable (URL) throws -> Void) {
        self.item = item
        self.inject = inject
    }

    static let unrelatedXattr = SafetyNetForeignItem(item: .xattr(name: "com.example.safetynet")) { url in
        try FileXattrs.set("com.example.safetynet", value: Data([0x53, 0x4E, 0x00, 0xFF, 0x01]), on: url)
    }
}

/// One format row of the safety net: a base fixture, the components the setup save writes into
/// it, and the foreign items planted afterwards.
struct SafetyNetRow: Sendable, Hashable, CustomTestStringConvertible {
    let name: String
    let fileType: AudioFileType
    let fixture: URL
    let components: Set<SafetyNetComponent>
    let foreignItems: [SafetyNetForeignItem]
    /// The container's own items for each component, beyond ``SafetyNetComponent/items``.
    var ownedItems: [SafetyNetComponent: [SafetyNetItem]] = [:]
    /// Plants a container family's foreign items in one pass, before each item's own injection.
    var plant: (@Sendable (URL) throws -> Void)?
    /// Changes the copied base fixture before the setup save, such as into another container form.
    var convert: (@Sendable (URL) throws -> Void)?

    var testDescription: String { name }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }

    func holds(_ component: SafetyNetComponent) -> Bool {
        components.contains(component)
    }

    func items(for component: SafetyNetComponent) -> [SafetyNetItem] {
        component.items + (ownedItems[component] ?? [])
    }

    /// The owned component an item belongs to; nil for a foreign item or the whole file.
    func component(of item: SafetyNetItem) -> SafetyNetComponent? {
        components.first { items(for: $0).contains(item) }
    }
}

// MARK: - Rows

extension SafetyNetRow {
    private static let common: Set<SafetyNetComponent> = {
        var result: Set<SafetyNetComponent> = [.tags, .rating, .artwork, .markers]
        #if os(macOS)
            result.insert(.finderTags)
        #endif
        return result
    }()

    static let mp3 = SafetyNetRow(
        name: "mp3", fileType: .mp3, fixture: TestBundleResources.shared.tabla_mp3,
        components: common.union([.packet]), foreignItems: SafetyNetID3Item.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetID3Item.ownedItems, plant: { try SafetyNetID3Plant.plant(in: $0) }
    )

    /// ADTS, which TagLib opens as an MPEG file. The base fixture has no tag of its own, so there
    /// are no other text frames to keep; it holds no markers.
    static let aac = SafetyNetRow(
        name: "aac", fileType: .aac, fixture: TestBundleResources.shared.tabla_aac,
        components: common.subtracting([.markers]), foreignItems: SafetyNetID3Item.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetID3Item.ownedItems.filter { $0.key != .markers && $0.key != .packet }.mapValues { $0.filter { $0 != .id3(.otherText) } },
        plant: { try SafetyNetID3Plant.plant(in: $0) }
    )

    static let wav = SafetyNetRow(
        name: "wav", fileType: .wav, fixture: TestBundleResources.shared.tabla_wav,
        components: common.union([.bext, .iXML, .packet]), foreignItems: SafetyNetRIFFItem.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetRIFFItem.ownedItems, plant: { try SafetyNetRIFFPlant.plant(in: $0) }
    )

    /// The wav row as RF64, whose markers go through Core Audio rather than TagLib, plus its
    /// long-form header.
    static let rf64 = SafetyNetRow(
        name: "rf64", fileType: .wav, fixture: TestBundleResources.shared.tabla_wav,
        components: common.union([.bext, .iXML, .packet]),
        foreignItems: SafetyNetRIFFItem.foreignItems + [SafetyNetForeignItem(item: .riff(.longForm)), .unrelatedXattr],
        ownedItems: SafetyNetRIFFItem.ownedItems, plant: { try SafetyNetRIFFPlant.plant(in: $0) },
        convert: { try RIFFChunkBuilder.convertToLongForm($0) }
    )

    /// The wav row with only an undated `bext` checked: a second fixture for one item.
    static let wavUndatedBEXT = SafetyNetRow(
        name: "wav-undated-bext", fileType: .wav, fixture: TestBundleResources.shared.tabla_wav,
        components: common.union([.bext, .iXML, .packet]), foreignItems: [],
        ownedItems: [.bext: [.riff(.bextDateTime)]], plant: { try SafetyNetRIFFPlant.plantUndatedBroadcastExtension(in: $0) }
    )

    /// The wav row's setup with every chunk moved ahead of `data`, as field recorders write them,
    /// checking only the audio and where it sits.
    static let wavRecorder = SafetyNetRow(
        name: "wav-recorder", fileType: .wav, fixture: TestBundleResources.shared.tabla_wav,
        components: common.union([.bext, .iXML, .packet]), foreignItems: [SafetyNetForeignItem(item: .riff(.dataOffset))],
        plant: { try SafetyNetRIFFPlant.plantRecorderLayout(in: $0) }
    )

    static let flac = SafetyNetRow(
        name: "flac", fileType: .flac, fixture: TestBundleResources.shared.tabla_flac,
        components: common.union([.bext, .iXML]), foreignItems: SafetyNetFLACItem.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetFLACItem.ownedItems, plant: { try SafetyNetFLACPlant.plant(in: $0) }
    )

    /// A FLAC whose BEXT is held only by iXML's `<BEXT>`, with only its block set checked: a
    /// second fixture for one item.
    static let flacIXMLOnlyBEXT = SafetyNetRow(
        name: "flac-ixml-only-bext", fileType: .flac, fixture: TestBundleResources.shared.flac_bext_ixml_external,
        components: common, foreignItems: [SafetyNetForeignItem(item: .flac(.blockSet))],
        plant: { try SafetyNetFLACPlant.plantIXMLOnlyBroadcastExtension(in: $0) }
    )

    static let aiff = SafetyNetRow(
        name: "aiff", fileType: .aiff, fixture: TestBundleResources.shared.tabla_aif,
        components: common, foreignItems: SafetyNetAIFFItem.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetAIFFItem.ownedItems, plant: { try SafetyNetAIFFPlant.plant(in: $0) }
    )

    /// The base fixture has no tag of its own, so there are no other text frames to keep.
    static let aifc = SafetyNetRow(
        name: "aifc", fileType: .aifc, fixture: TestBundleResources.shared.sine_aifc,
        components: common, foreignItems: SafetyNetAIFFItem.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetAIFFItem.ownedItems.mapValues { $0.filter { $0 != .id3(.otherText) } },
        plant: { try SafetyNetAIFFPlant.plant(in: $0) }
    )

    static let ogg = SafetyNetRow(
        name: "ogg", fileType: .ogg, fixture: TestBundleResources.shared.tabla_ogg,
        components: common, foreignItems: SafetyNetOggItem.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetOggItem.ownedItems, plant: { try SafetyNetOggPlant.plant(in: $0, base: TestBundleResources.shared.tabla_ogg) }
    )

    /// The base fixture's only field is its encoder, so there are no other fields to keep.
    static let opus = SafetyNetRow(
        name: "opus", fileType: .opus, fixture: TestBundleResources.shared.sine_opus,
        components: common, foreignItems: SafetyNetOggItem.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetOggItem.ownedItems.mapValues { $0.filter { $0 != .ogg(.otherFields) } },
        plant: { try SafetyNetOggPlant.plant(in: $0, base: TestBundleResources.shared.sine_opus) }
    )

    /// `stik` 1, music.
    static let m4a = SafetyNetRow(
        name: "m4a", fileType: .m4a, fixture: TestBundleResources.shared.tabla_m4a,
        components: common, foreignItems: SafetyNetMP4Item.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetMP4Item.ownedItems, plant: { try SafetyNetMP4Plant.plant(in: $0, mediaKind: 1) }
    )

    /// `stik` 2, which makes Apple Books and Music treat the file as an audiobook.
    static let m4b = SafetyNetRow(
        name: "m4b", fileType: .m4b, fixture: TestBundleResources.shared.sine_m4b,
        components: common, foreignItems: SafetyNetMP4Item.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetMP4Item.ownedItems, plant: { try SafetyNetMP4Plant.plant(in: $0, mediaKind: 2) }
    )

    static let mp4 = SafetyNetRow(
        name: "mp4", fileType: .mp4, fixture: TestBundleResources.shared.tabla_mp4,
        components: common, foreignItems: SafetyNetMP4Item.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetMP4Item.ownedItems, plant: { try SafetyNetMP4Plant.plant(in: $0, mediaKind: 1) }
    )

    /// `stik` 6, music video.
    static let m4v = SafetyNetRow(
        name: "m4v", fileType: .m4v, fixture: TestBundleResources.shared.sine_m4v,
        components: common, foreignItems: SafetyNetMP4Item.foreignItems + [.unrelatedXattr],
        ownedItems: SafetyNetMP4Item.ownedItems, plant: { try SafetyNetMP4Plant.plant(in: $0, mediaKind: 6) }
    )

    /// Classic QuickTime `udta` text atoms in the base fixture, and no `ilst` of its own, so there
    /// are no other items to keep.
    static let mov = SafetyNetRow(
        name: "mov", fileType: .mov, fixture: TestBundleResources.shared.qtmeta_mov,
        components: common, foreignItems: SafetyNetMP4Item.quickTimeForeignItems + [.unrelatedXattr],
        ownedItems: SafetyNetMP4Item.ownedItems.mapValues { $0.filter { $0 != .mp4(.otherItems) } },
        plant: { try SafetyNetMP4Plant.plant(in: $0, mediaKind: 6, quickTime: true) }
    )

    private static let matroskaComponents = common.subtracting([.markers])

    /// Its own `Chapters` already.
    static let mka = SafetyNetRow(
        name: "mka", fileType: .mka, fixture: TestBundleResources.shared.tabla_mka,
        components: matroskaComponents, foreignItems: SafetyNetMatroskaItem.foreignItems(font: true) + [.unrelatedXattr],
        ownedItems: SafetyNetMatroskaItem.ownedItems, plant: { try SafetyNetMatroskaPlant.plant(in: $0, font: true) }
    )

    static let mkv = SafetyNetRow(
        name: "mkv", fileType: .mkv, fixture: TestBundleResources.shared.sample_mkv,
        components: matroskaComponents, foreignItems: SafetyNetMatroskaItem.foreignItems(font: true) + [.unrelatedXattr],
        ownedItems: SafetyNetMatroskaItem.ownedItems, plant: { try SafetyNetMatroskaPlant.plant(in: $0, font: true) }
    )

    static let webm = SafetyNetRow(
        name: "webm", fileType: .webm, fixture: TestBundleResources.shared.sample_webm,
        components: matroskaComponents, foreignItems: SafetyNetMatroskaItem.foreignItems(font: false) + [.unrelatedXattr],
        ownedItems: SafetyNetMatroskaItem.ownedItems, plant: { try SafetyNetMatroskaPlant.plant(in: $0, font: false) }
    )

    /// The formats ShadowTag users edit.
    static let slice: [SafetyNetRow] = [mp3, wav, flac, m4a, m4b]
}

// MARK: - Setup values

/// What the setup save writes. A save kind's edit changes one of these, so each must differ from
/// the kind's own value.
enum SafetyNetSetup {
    static let title = "Safety Net"
    static let rating = "4"
    static let customTagKey = "SAFETYNET"
    static let customTagValue = "Setup"
    static let markers = [
        AudioMarkerDescription(name: "Setup One", startTime: 0.1),
        AudioMarkerDescription(name: "Setup Two", startTime: 0.3),
    ]
    static let bextSequenceDescription = "Safety Net BEXT"
    static let bextOriginator = "SafetyNet"
    static let iXMLProject = "Safety Net Project"
    static let iXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <BWFXML><IXML_VERSION>1.61</IXML_VERSION><PROJECT>\(iXMLProject)</PROJECT><NOTE>Setup</NOTE></BWFXML>
    """
    static let packet = xmpPacket(title: "Setup")
    static let finderTag = "Safety Net"

    static func xmpPacket(title: String) -> String {
        """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>\
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">\
        <dc:title><rdf:Alt><rdf:li xml:lang="x-default">\(title)</rdf:li></rdf:Alt></dc:title>\
        </rdf:Description></rdf:RDF></x:xmpmeta><?xpacket end="w"?>
        """
    }

    static func picture(_ url: URL) throws -> TagPictureRef {
        try #require(TagPictureRef(url: url, pictureDescription: "", pictureType: ""))
    }
}

// MARK: - Fixture

extension SafetyNetRow {
    /// Copies the base fixture into `bin`, writes every owned component through
    /// `MetaAudioFileDescription.save`, then plants the foreign items byte-level, so no writer of
    /// ours touches them during setup.
    func prepare(in bin: URL) async throws -> URL {
        let url = bin.appendingPathComponent("\(name)-\(fixture.lastPathComponent)")
        try FileManager.default.copyItem(at: fixture, to: url)
        try convert?(url)

        var description = try await MetaAudioFileDescription(parsing: url)
        var flags: Set<MetadataDirtyFlag> = [.tags]

        description.tagProperties[.title] = SafetyNetSetup.title
        description.tagProperties.data.set(customTag: SafetyNetSetup.customTagKey, value: SafetyNetSetup.customTagValue)
        description.tagProperties[.rating] = SafetyNetSetup.rating

        if holds(.artwork) {
            description.artwork.pictureRef = try SafetyNetSetup.picture(TestBundleResources.shared.sharksandwich)
            flags.insert(.artwork)
        }

        if holds(.markers) {
            description.markerCollection = AudioMarkerDescriptionCollection(markerDescriptions: SafetyNetSetup.markers)
            flags.insert(.markers)
        }

        if holds(.bext) {
            var bext = BEXTDescription()
            bext.sequenceDescription = SafetyNetSetup.bextSequenceDescription
            bext.originator = SafetyNetSetup.bextOriginator
            description.bextDescription = bext
        }

        if holds(.iXML) {
            description.iXMLMetadata = SafetyNetSetup.iXML
        }

        #if os(macOS)
            if holds(.finderTags) {
                description.urlProperties.finderTags = FinderTagGroup(tags: [FinderTagDescription(label: SafetyNetSetup.finderTag)])
                flags.insert(.finderTags)
            }
        #endif

        try description.save(dirtyFlags: flags, storedXMPPacket: holds(.packet) ? .replace(SafetyNetSetup.packet) : .keep)

        try await requireSetupWritten(to: url)

        try plant?(url)

        for foreign in foreignItems {
            try foreign.inject(url)
        }

        return url
    }

    /// The setup save, checked through our own reader. This guards the fixture, not the save under
    /// test: a component the setup failed to write would let every later cell pass vacuously.
    private func requireSetupWritten(to url: URL) async throws {
        let reread = try await MetaAudioFileDescription(parsing: url)
        let context = Comment(rawValue: "\(name) setup save")

        try #require(reread.tagProperties[.title] == SafetyNetSetup.title, context)
        try #require(reread.tagProperties.data.customTag(for: SafetyNetSetup.customTagKey) == SafetyNetSetup.customTagValue, context)
        try #require(reread.tagProperties[.rating] == SafetyNetSetup.rating, context)

        if holds(.artwork) {
            try #require(reread.artwork.cgImage != nil, context)
        }

        if holds(.markers) {
            try #require(reread.markerCollection.markerDescriptions.map(\.name) == SafetyNetSetup.markers.map(\.name), context)
        }

        if holds(.bext) {
            try #require(reread.bextDescription?.sequenceDescription == SafetyNetSetup.bextSequenceDescription, context)
        }

        if holds(.iXML) {
            try #require(reread.iXMLMetadata?.contains(SafetyNetSetup.iXMLProject) == true, context)
        }

        if holds(.packet) {
            try #require(StoredXMPPacketWrite.storedPacket(in: url) == SafetyNetSetup.packet, context)
        }
    }
}
