// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase

extension MetaAudioFileDescription {
    /// Syncs UCS category/subcategory/catID into the iXML USER container.
    ///
    /// Skips files with no existing iXML when all values are nil (avoids creating
    /// empty iXML chunks on reset).
    public mutating func syncUCSToIXML(category: String?, subCategory: String?, catID: String?) {
        let ucs = UCSUserFields(category: category, subCategory: subCategory, catID: catID)
        guard !ucs.isEmpty || iXMLMetadata != nil else { return }
        var ixml = iXMLMetadata.flatMap { try? IXMLMetadata(xml: $0) } ?? IXMLMetadata()
        ixml.setUCSFields(ucs)
        iXMLMetadata = ixml.xml
    }
}
