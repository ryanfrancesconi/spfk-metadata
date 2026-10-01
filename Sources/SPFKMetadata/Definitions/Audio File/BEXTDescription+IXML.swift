// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase

extension BEXTDescription {
    /// From iXML's `<BEXT>` element, for a FLAC with no BEXT block (Sequoia writes it there). Nil
    /// when the element has nothing recognizable.
    public init?(ixmlMetadata: IXMLMetadata) {
        guard ixmlMetadata.bextOriginator != nil ||
            ixmlMetadata.bextOriginationDate != nil ||
            ixmlMetadata.bextOriginationTime != nil ||
            ixmlMetadata.bextDescriptionText != nil ||
            ixmlMetadata.bextCodingHistory != nil ||
            ixmlMetadata.bextTimeReferenceLow != nil ||
            ixmlMetadata.bextTimeReferenceHigh != nil
        else { return nil }

        self.init()

        if let v: Int16 = IXMLMetadata.number(ixmlMetadata.bextVersion) {
            version = v
        }

        sequenceDescription = ixmlMetadata.bextDescriptionText
        originator = ixmlMetadata.bextOriginator
        originatorReference = ixmlMetadata.bextOriginatorReference
        originationDate = ixmlMetadata.bextOriginationDate
        originationTime = ixmlMetadata.bextOriginationTime
        codingHistory = ixmlMetadata.bextCodingHistory
        umid = ixmlMetadata.bextUMID

        if let low: UInt64 = IXMLMetadata.number(ixmlMetadata.bextTimeReferenceLow) {
            timeReferenceLow = low
        }

        if let high: UInt64 = IXMLMetadata.number(ixmlMetadata.bextTimeReferenceHigh) {
            timeReferenceHigh = high
        }
    }
}
