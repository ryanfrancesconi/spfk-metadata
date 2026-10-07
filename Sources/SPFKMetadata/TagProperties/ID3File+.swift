// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension ID3File {
    subscript(id3 key: ID3FrameKey) -> String? {
        dictionary?[key.value] as? String
    }
}
