// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
@preconcurrency import AEXML

/// Structured UCS fields extracted from the iXML `<USER>` container.
///
/// Soundminer and other UCS-aware tools embed these in the BWFXML USER element:
/// ```xml
/// <USER>
///     <CATEGORY>EXPLOSIONS</CATEGORY>
///     <SUBCATEGORY>DESIGNED</SUBCATEGORY>
///     <CATID>EXPLDsgn</CATID>
/// </USER>
/// ```
public struct UCSUserFields: Sendable, Equatable {
    public var category: String?
    public var subCategory: String?
    public var catID: String?

    public var isEmpty: Bool {
        category == nil && subCategory == nil && catID == nil
    }
}

extension IXMLMetadata {
    // MARK: - UCS Read

    /// Parses UCS fields from the raw ``userContent`` XML string.
    ///
    /// Returns `nil` if there is no user content or no UCS fields are present.
    public var ucsFields: UCSUserFields? {
        guard let userContent, let doc = try? AEXMLDocument(xml: userContent) else { return nil }

        let root = doc.root
        let fields = UCSUserFields(
            category: root["CATEGORY"].value,
            subCategory: root["SUBCATEGORY"].value,
            catID: root["CATID"].value
        )

        return fields.isEmpty ? nil : fields
    }

    // MARK: - UCS Write

    /// Merges UCS fields into the ``userContent`` XML, preserving all other vendor elements.
    ///
    /// If `userContent` is nil, a minimal USER element is created containing only the UCS fields.
    public mutating func setUCSFields(_ ucs: UCSUserFields) {
        // Parse existing content, or start fresh
        let doc: AEXMLDocument
        if let existing = userContent, let parsed = try? AEXMLDocument(xml: existing) {
            doc = parsed
        } else {
            doc = AEXMLDocument()
            doc.addChild(name: "USER")
        }

        let root = doc.root

        // Set or replace each UCS element, leaving all other children untouched
        setElement(in: root, name: "CATEGORY", value: ucs.category)
        setElement(in: root, name: "SUBCATEGORY", value: ucs.subCategory)
        setElement(in: root, name: "CATID", value: ucs.catID)

        userContent = doc.xml
    }

    // MARK: - Private helpers

    private func setElement(in parent: AEXMLElement, name: String, value: String?) {
        if let existing = parent.children.first(where: { $0.name == name }) {
            existing.value = value
        } else if let value {
            parent.addChild(name: name, value: value)
        }
    }
}
