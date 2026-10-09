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

    /// The components a failed `save()` could not write, short of the whole file.
    var failedWrites: Set<MetadataComponent> {
        var result = Set<MetadataComponent>()
        if failedComponents.contains(.artwork) { result.insert(.artwork) }
        if failedComponents.contains(.markers) { result.insert(.markers) }
        if failedComponents.contains(.rating) { result.insert(.rating) }
        return result
    }

    /// The component a failed `save()` reports; `.tags` when nothing was written.
    var failedComponent: MetadataComponent {
        if failedComponents.contains(.container) { return .tags }
        if failedComponents.contains(.artwork) { return .artwork }
        if failedComponents.contains(.markers) { return .markers }
        return .rating
    }
}
