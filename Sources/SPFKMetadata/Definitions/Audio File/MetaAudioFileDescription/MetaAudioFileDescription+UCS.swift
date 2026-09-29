// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase

extension MetaAudioFileDescription {
    /// Syncs UCS category/subcategory/catID into the iXML USER container. All-nil values on a
    /// file with no iXML are a no-op, so a reset creates no empty chunk. iXML that does not parse
    /// is left as it is.
    public mutating func syncUCSToIXML(category: String?, subCategory: String?, catID: String?) {
        let ucs = UCSUserFields(category: category, subCategory: subCategory, catID: catID)
        guard !ucs.isEmpty || iXMLMetadata != nil else { return }

        var ixml = IXMLMetadata()
        if let iXMLMetadata {
            do {
                ixml = try IXMLMetadata(xml: iXMLMetadata)
            } catch {
                Log.error("iXML does not parse, UCS fields not written:", error)
                return
            }
        }

        ixml.setUCSFields(ucs)
        iXMLMetadata = ixml.xml
    }
}
