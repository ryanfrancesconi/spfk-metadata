// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension FlacFileC {
    var bextDescription: BEXTDescription? {
        get {
            guard let bextDescriptionC else { return nil }
            return BEXTDescription(info: bextDescriptionC)
        }

        set {
            guard let newValue else {
                bextDescriptionC = nil
                return
            }

            bextDescriptionC = newValue.bextDescriptionC
        }
    }

    /// The BEXT block, or iXML's `<BEXT>` element where Sequoia writes it, validated.
    var parsedBEXT: BEXTDescription? {
        if let bext = bextDescription?.validated() {
            return bext
        }

        guard let iXML, let ixml = try? IXMLMetadata(xml: iXML) else { return nil }
        return BEXTDescription(ixmlMetadata: ixml)?.validated()
    }
}
