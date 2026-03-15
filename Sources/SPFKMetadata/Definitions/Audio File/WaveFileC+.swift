// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataC
import SPFKMetadataBase

/// Swift convenience accessors on the `WaveFileC` Objective-C class, providing typed
/// BEXT, INFO frame, and ID3 frame subscript access without manual dictionary key management.
extension WaveFileC {
    /// The BEXT chunk as a Swift `BEXTDescription`, converting to/from `BEXTDescriptionC` automatically.
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

    /// Reads or writes a RIFF INFO chunk tag by its `InfoFrameKey`.
    public subscript(info key: InfoFrameKey) -> String? {
        get { infoDictionary[key.value] as? String }
        set {
            infoDictionary[key.value] = newValue
        }
    }

    /// Reads or writes an ID3v2 frame by its `ID3FrameKey`.
    public subscript(id3 key: ID3FrameKey) -> String? {
        get { id3Dictionary[key.value] as? String }
        set {
            id3Dictionary[key.value] = newValue
        }
    }
}
