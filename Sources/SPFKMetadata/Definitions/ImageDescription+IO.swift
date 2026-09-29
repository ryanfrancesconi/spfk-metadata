// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreImage
import Foundation
import SPFKMetadataBase
import SPFKMetadataC

extension ImageDescription {
    /// The getter keeps the image's own type, else PNG when it has alpha and JPEG when not.
    public var pictureRef: TagPictureRef? {
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
                pictureType: ""
            )

            return pictureRef
        }

        set {
            cgImage = newValue?.cgImage

            if let desc = newValue?.pictureDescription, desc != "" {
                description = desc
            }
        }
    }
}
