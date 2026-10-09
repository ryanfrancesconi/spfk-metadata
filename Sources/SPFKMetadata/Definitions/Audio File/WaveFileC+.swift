// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension WaveFileC {
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

    subscript(info key: InfoFrameKey) -> String? {
        get { infoDictionary[key.value] as? String }
        set {
            infoDictionary[key.value] = newValue
        }
    }

    /// The component a failed `save()` reports; `.tags` when nothing was written.
    var failedComponent: MetadataError.Component {
        if failedComponents.contains(.container) { return .tags }
        if failedComponents.contains(.artwork) { return .artwork }
        if failedComponents.contains(.markers) { return .markers }
        return .rating
    }
}
