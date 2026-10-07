// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension TagPictureRef {
    /// Throws when the file has no picture that decodes.
    static func parsing(url: URL) throws -> TagPictureRef {
        guard let pictureRef: TagPictureRef = TagPicture(path: url.path)?.pictureRef else {
            throw NSError(file: #file, function: #function, description: "Failed to find picture in \(url)")
        }

        return pictureRef
    }
}
