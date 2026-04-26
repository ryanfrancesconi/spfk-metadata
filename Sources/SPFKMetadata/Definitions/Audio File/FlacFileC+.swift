// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
import SPFKMetadataC

/// Swift convenience accessors on the `FlacFileC` Objective-C class, providing a typed
/// BEXT accessor without manual C bridge object management.
extension FlacFileC {
    /// The BEXT APPLICATION block as a Swift `BEXTDescription`, converting to/from `BEXTDescriptionC` automatically.
    public var bextDescription: BEXTDescription? {
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
}
