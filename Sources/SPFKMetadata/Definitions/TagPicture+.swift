import Foundation
import SPFKMetadataBase
import SPFKMetadataC

extension TagPictureRef {
    /// Extracts the embedded artwork from the audio file at the given URL via TagLib.
    /// - Parameter url: URL to the audio file.
    /// - Returns: A `TagPictureRef` containing the artwork `CGImage` and UTType.
    /// - Throws: If no embedded picture is found.
    public static func parsing(url: URL) throws -> TagPictureRef {
        guard let pictureRef: TagPictureRef = TagPicture(path: url.path)?.pictureRef else {
            throw NSError(file: #file, function: #function, description: "Failed to find picture in \(url)")
        }

        return pictureRef
    }
}
