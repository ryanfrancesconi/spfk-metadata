// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase

extension BEXTDescription {
    /// Creates a `BEXTDescription` from the BEXT container fields embedded in an iXML document.
    ///
    /// Used as a fallback when a FLAC file carries no binary BEXT APPLICATION block but does
    /// carry iXML with a `<BEXT>` element (e.g. files produced by Steinberg Sequoia).
    /// Returns `nil` if the iXML document contains no recognizable BEXT content.
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

        if let versionString = ixmlMetadata.bextVersion, let v = Int16(versionString) {
            version = v
        }

        sequenceDescription = ixmlMetadata.bextDescriptionText
        originator = ixmlMetadata.bextOriginator
        originatorReference = ixmlMetadata.bextOriginatorReference
        originationDate = ixmlMetadata.bextOriginationDate
        originationTime = ixmlMetadata.bextOriginationTime
        codingHistory = ixmlMetadata.bextCodingHistory
        umid = ixmlMetadata.bextUMID

        if let lowString = ixmlMetadata.bextTimeReferenceLow, let low = UInt64(lowString) {
            timeReferenceLow = low
        }

        if let highString = ixmlMetadata.bextTimeReferenceHigh, let high = UInt64(highString) {
            timeReferenceHigh = high
        }
    }
}
