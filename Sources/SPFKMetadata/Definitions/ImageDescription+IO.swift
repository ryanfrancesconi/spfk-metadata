// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreImage
import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension ImageDescription {
    /// `description` is the picture's when it has one, else nil.
    public init(embeddedArtwork: EmbeddedArtwork) {
        self.init()
        cgImage = embeddedArtwork.cgImage

        if embeddedArtwork.pictureDescription != "" {
            description = embeddedArtwork.pictureDescription
        }
    }

    /// TagLib's name for picture type 3.
    private static let frontCoverPictureType = "Front Cover"

    /// The getter keeps the image's own file type, else PNG when it has alpha and JPEG when not, and
    /// always describes the front cover: the setter keeps no picture type.
    var pictureRef: TagPictureRef? {
        get {
            guard let cgImage else {
                return nil
            }

            var utType: UTType = .jpeg

            if let value = cgImage.utType as? String, let utValue = UTType(value) {
                utType = utValue

            } else if cgImage.alphaInfo != .none, cgImage.alphaInfo != .noneSkipLast,
                      cgImage.alphaInfo != .noneSkipFirst
            {
                utType = .png
            }

            let pictureRef = TagPictureRef(
                image: cgImage,
                utType: utType,
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
