// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataC
import SPFKMetadataBase

/// Swift typed subscript on the `ID3File` Objective-C class for reading and writing ID3 frames.
extension ID3File {
    /// Reads or writes an ID3v2 frame by its ``ID3FrameKey``.
    public subscript(id3 key: ID3FrameKey) -> String? {
        get { dictionary?[key.value] as? String }
        set {
            dictionary?[key.value] = newValue
        }
    }
}
