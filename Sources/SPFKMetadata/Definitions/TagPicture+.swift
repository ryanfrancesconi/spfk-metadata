
import Foundation
import SPFKMetadataC

extension TagPictureRef {
    public static func parsing(url: URL) throws -> TagPictureRef {
        /// pull embedded image out of the metadata if it exists
        guard let pictureRef: TagPictureRef = TagPicture(path: url.path)?.pictureRef else {
            throw NSError(file: #file, function: #function, description: "Failed to find picture in \(url)")
        }

        return pictureRef
    }
}
