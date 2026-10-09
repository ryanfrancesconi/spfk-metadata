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

    /// The front cover, else the first picture, with the bytes the file stores. Nil when the file
    /// has none; throws `MetadataError.readFailed` when it can't be opened or its picture doesn't decode.
    static func reading(url: URL) throws -> TagPictureRef? {
        var result = TagPictureReadResult.found
        let pictureRef = TagPicture.readPath(url.path, result: &result)

        switch result {
        case .none:
            return nil

        case .found:
            guard let pictureRef else { throw MetadataError.readFailed(.artwork, url) }
            return pictureRef

        case .openFailed, .decodeFailed:
            throw MetadataError.readFailed(.artwork, url)

        @unknown default:
            throw MetadataError.readFailed(.artwork, url)
        }
    }
}
