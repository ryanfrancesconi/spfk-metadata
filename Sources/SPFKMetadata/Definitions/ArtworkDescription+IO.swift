// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreImage
import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension ArtworkDescription {
    /// `description` is the picture's when it has one, else nil.
    public init(embeddedArtwork: EmbeddedArtwork) {
        self.init()
        cgImage = embeddedArtwork.cgImage

        if embeddedArtwork.pictureDescription != "" {
            description = embeddedArtwork.pictureDescription
        }
    }

    /// The file's artwork as `EmbeddedArtwork.read(from:)` finds it, holding the bytes the file
    /// stores so that writing it back leaves them unchanged. Nil when the file has none.
    public static func read(from url: URL) throws -> ArtworkDescription? {
        guard let pictureRef = try TagPictureRef.reading(url: url) else { return nil }

        var artwork = ArtworkDescription()
        artwork.pictureRef = pictureRef
        return artwork
    }

    /// TagLib's name for picture type 3.
    private static let frontCoverPictureType = "Front Cover"

    /// The getter's type is the one the image is embedded in, and it always describes the front
    /// cover: the setter keeps no picture type.
    var pictureRef: TagPictureRef? {
        get {
            guard let cgImage else {
                return nil
            }

            let pictureRef = TagPictureRef(
                image: cgImage,
                utType: EmbeddedArtwork.embeddedType(of: cgImage),
                pictureDescription: description ?? "",
                pictureType: Self.frontCoverPictureType
            )

            pictureRef.storedData = storedPicture?.data
            pictureRef.storedMimeType = storedPicture?.mimeType

            return pictureRef
        }

        set {
            if let newValue, let data = newValue.storedData, let mimeType = newValue.storedMimeType {
                setImage(newValue.cgImage, storedAs: StoredPicture(data: data, mimeType: mimeType))
            } else {
                cgImage = newValue?.cgImage
            }

            if let desc = newValue?.pictureDescription, desc != "" {
                description = desc
            }
        }
    }
}
