// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
@preconcurrency import AEXML

/// Structured fields from the iXML `<ASWG>` container.
///
/// The Audio Services Working Group (ASWG) container appears as a top-level sibling
/// of `<USER>` in the BWFXML root. Unlike other iXML containers, its child element
/// names use lowercase camelCase rather than UPPERCASE_UNDERSCORE.
///
/// Spec: https://www.aswg.audio/
public struct IXMLASWGFields: Sendable, Equatable {
    public var songTitle: String?
    public var composer: String?
    public var musicPublisher: String?
    public var library: String?
    public var category: String?
    public var subCategory: String?
    public var catId: String?
    public var userCategory: String?
    public var originator: String?
    public var notes: String?
    public var inKey: String?
    public var tempo: String?
    public var micType: String?
    public var isrcId: String?

    public var isEmpty: Bool {
        [songTitle, composer, musicPublisher, library, category, subCategory,
         catId, userCategory, originator, notes, inKey, tempo, micType, isrcId]
            .allSatisfy { $0 == nil }
    }

    public init() {}
}

// MARK: - Field map

/// Ordered mapping from `IXMLASWGFields` key path to XML element name (camelCase per ASWG spec).
nonisolated(unsafe) let iXMLASWGFieldMap: [(keyPath: WritableKeyPath<IXMLASWGFields, String?>, xmlName: String)] = [
    (\.songTitle, "songTitle"),
    (\.composer, "composer"),
    (\.musicPublisher, "musicPublisher"),
    (\.library, "library"),
    (\.category, "category"),
    (\.subCategory, "subCategory"),
    (\.catId, "catId"),
    (\.userCategory, "userCategory"),
    (\.originator, "originator"),
    (\.notes, "notes"),
    (\.inKey, "inKey"),
    (\.tempo, "tempo"),
    (\.micType, "micType"),
    (\.isrcId, "isrcId"),
]

// MARK: - IXMLMetadata extension

extension IXMLMetadata {
    // MARK: - ASWG Read

    /// Parses ASWG fields from the raw ``aswgContent`` XML string.
    ///
    /// Returns `nil` if there is no ASWG content or all fields are empty.
    public var aswgFields: IXMLASWGFields? {
        guard let aswgContent, let doc = try? AEXMLDocument(xml: aswgContent) else { return nil }
        let root = doc.root
        var fields = IXMLASWGFields()
        for (keyPath, name) in iXMLASWGFieldMap {
            fields[keyPath: keyPath] = root[name].value
        }
        return fields.isEmpty ? nil : fields
    }

    // MARK: - ASWG Write

    /// Merges the given fields into ``aswgContent``, preserving all other ASWG elements.
    ///
    /// If ``aswgContent`` is nil, a minimal ASWG element is created.
    public mutating func setASWGFields(_ fields: IXMLASWGFields) {
        let doc: AEXMLDocument
        if let existing = aswgContent, let parsed = try? AEXMLDocument(xml: existing) {
            doc = parsed
        } else {
            doc = AEXMLDocument()
            doc.addChild(name: IXMLElement.aswg.rawValue)
        }

        let root = doc.root
        for (keyPath, name) in iXMLASWGFieldMap {
            setASWGElement(in: root, name: name, value: fields[keyPath: keyPath])
        }

        aswgContent = doc.xml
    }

    // MARK: - Private helpers

    private func setASWGElement(in parent: AEXMLElement, name: String, value: String?) {
        if let existing = parent.children.first(where: { $0.name == name }) {
            existing.value = value
        } else if let value {
            parent.addChild(name: name, value: value)
        }
    }
}
