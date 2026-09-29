// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
@preconcurrency import AEXML
import SPFKBase

/// The iXML `<ASWG>` container (https://www.aswg.audio/). Unlike the rest of iXML, its element names
/// are camelCase.
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

    /// Parsed from ``aswgContent`` on every access. Nil when there is none or every field is empty.
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

    /// Merges into ``aswgContent``, creating it if needed; unmodeled ASWG elements are kept.
    /// Content that does not parse is left as it is and the fields are not written.
    public mutating func setASWGFields(_ fields: IXMLASWGFields) {
        let doc: AEXMLDocument
        if let existing = aswgContent {
            do {
                doc = try AEXMLDocument(xml: existing)
            } catch {
                Log.error("ASWG content does not parse, fields not written:", error)
                return
            }
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
