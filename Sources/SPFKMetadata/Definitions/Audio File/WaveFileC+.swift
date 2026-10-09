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
}

extension WaveFileComponents {
    /// The components a failed `save()` could not write, short of the whole file.
    var failedWrites: Set<MetadataComponent> {
        var result = Set<MetadataComponent>()
        if contains(.artwork) { result.insert(.artwork) }
        if contains(.markers) { result.insert(.markers) }
        if contains(.rating) { result.insert(.rating) }
        return result
    }

    /// What a save of `attempted` throws when it wrote the file but not these components.
    func incompleteSave(attempted: Set<MetadataComponent>, url: URL) -> MetadataError {
        let failed = failedWrites
        return .incompleteSave(
            written: attempted.subtracting(failed),
            failures: MetadataComponent.allCases.filter(failed.contains).map { .writeFailed($0, url) }
        )
    }
}
