// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
@preconcurrency import AEXML

/// Full set of user-defined fields from the iXML `<USER>` container.
///
/// Written by Soundminer and other sample library tools as flat child elements of `<USER>`.
/// Unknown child elements are preserved during round-trips via ``IXMLMetadata/userContent``.
public struct IXMLUserFields: Sendable, Equatable {
    public var trackTitle: String?
    public var artist: String?
    public var composer: String?
    public var publisher: String?
    public var library: String?
    public var cdTitle: String?
    public var category: String?
    public var subCategory: String?
    public var catID: String?
    public var userCategory: String?
    public var vendorCategory: String?
    public var categoryFull: String?
    public var description: String?
    public var notes: String?
    public var userComments: String?
    public var keywords: String?
    public var bpm: String?
    public var microphone: String?
    public var micPerspective: String?
    public var recType: String?
    public var recMedium: String?
    public var source: String?
    public var location: String?
    public var show: String?
    public var designer: String?
    public var manufacturer: String?
    public var track: String?
    public var shortID: String?
    public var longID: String?
    public var url: String?
    public var rating: String?
    public var trackYear: String?
    public var releaseDate: String?
    public var shootDate: String?
    public var openTier: String?
    public var fxName: String?
    public var volume: String?
    public var embedder: String?

    public var isEmpty: Bool {
        [trackTitle, artist, composer, publisher, library, cdTitle,
         category, subCategory, catID, userCategory, vendorCategory,
         categoryFull, description, notes, userComments, keywords, bpm,
         microphone, micPerspective, recType, recMedium, source, location,
         show, designer, manufacturer, track, shortID, longID, url,
         rating, trackYear, releaseDate, shootDate, openTier, fxName,
         volume, embedder].allSatisfy { $0 == nil }
    }

    public init() {}
}

// MARK: - Field map

/// Ordered mapping from `IXMLUserFields` key path to XML element name.
/// Order defines the display order in editors.
nonisolated(unsafe) let iXMLUserFieldMap: [(keyPath: WritableKeyPath<IXMLUserFields, String?>, xmlName: String)] = [
    (\.trackTitle, "TRACKTITLE"),
    (\.artist, "ARTIST"),
    (\.composer, "COMPOSER"),
    (\.publisher, "PUBLISHER"),
    (\.library, "LIBRARY"),
    (\.cdTitle, "CDTITLE"),
    (\.category, "CATEGORY"),
    (\.subCategory, "SUBCATEGORY"),
    (\.catID, "CATID"),
    (\.userCategory, "USERCATEGORY"),
    (\.vendorCategory, "VENDORCATEGORY"),
    (\.categoryFull, "CATEGORYFULL"),
    (\.description, "DESCRIPTION"),
    (\.notes, "NOTES"),
    (\.userComments, "USERCOMMENTS"),
    (\.keywords, "KEYWORDS"),
    (\.bpm, "BPM"),
    (\.microphone, "MICROPHONE"),
    (\.micPerspective, "MICPERSPECTIVE"),
    (\.recType, "RECTYPE"),
    (\.recMedium, "RECMEDIUM"),
    (\.source, "SOURCE"),
    (\.location, "LOCATION"),
    (\.show, "SHOW"),
    (\.designer, "DESIGNER"),
    (\.manufacturer, "MANUFACTURER"),
    (\.track, "TRACK"),
    (\.shortID, "SHORTID"),
    (\.longID, "LONGID"),
    (\.url, "URL"),
    (\.rating, "RATING"),
    (\.trackYear, "TRACKYEAR"),
    (\.releaseDate, "RELEASEDATE"),
    (\.shootDate, "SHOOTDATE"),
    (\.openTier, "OPENTIER"),
    (\.fxName, "FXNAME"),
    (\.volume, "VOLUME"),
    (\.embedder, "EMBEDDER"),
]

// MARK: - IXMLMetadata extension

extension IXMLMetadata {
    // MARK: - USER Read

    /// Parses all known USER fields from the raw ``userContent`` XML string.
    ///
    /// Returns `nil` if there is no user content or all fields are empty.
    public var userFields: IXMLUserFields? {
        guard let userContent, let doc = try? AEXMLDocument(xml: userContent) else { return nil }
        let root = doc.root
        var fields = IXMLUserFields()
        for (keyPath, name) in iXMLUserFieldMap {
            fields[keyPath: keyPath] = root[name].value
        }
        return fields.isEmpty ? nil : fields
    }

    // MARK: - USER Write

    /// Merges the given fields into ``userContent``, preserving all other vendor elements.
    ///
    /// If ``userContent`` is nil, a minimal USER element is created.
    public mutating func setUserFields(_ fields: IXMLUserFields) {
        let doc: AEXMLDocument
        if let existing = userContent, let parsed = try? AEXMLDocument(xml: existing) {
            doc = parsed
        } else {
            doc = AEXMLDocument()
            doc.addChild(name: IXMLElement.user.rawValue)
        }

        let root = doc.root
        for (keyPath, name) in iXMLUserFieldMap {
            setUserElement(in: root, name: name, value: fields[keyPath: keyPath])
        }

        userContent = doc.xml
    }

    // MARK: - Private helpers

    private func setUserElement(in parent: AEXMLElement, name: String, value: String?) {
        if let existing = parent.children.first(where: { $0.name == name }) {
            existing.value = value
        } else if let value {
            parent.addChild(name: name, value: value)
        }
    }
}
