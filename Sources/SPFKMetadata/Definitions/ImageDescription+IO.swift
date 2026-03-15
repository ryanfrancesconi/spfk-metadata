// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreImage
import Foundation
import SPFKMetadataC
import SPFKMetadataBase

extension ImageDescription {
    /// Converts to/from `TagPictureRef` for reading and writing embedded artwork via TagLib.
    /// On get, selects JPEG or PNG UTType based on the image's alpha channel.
    public var pictureRef: TagPictureRef? {
        get {
            guard let cgImage else {
                return nil
            }

            var utType: UTType = .jpeg

            if let value = cgImage.utType as? String, let utValue = UTType(value) {
                utType = utValue
            } else if cgImage.alphaInfo != .none && cgImage.alphaInfo != .noneSkipLast && cgImage.alphaInfo != .noneSkipFirst {
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
            guard let newValue else { return }

            cgImage = newValue.cgImage

            if let desc = newValue.pictureDescription, desc != "" {
                description = desc
            }
        }
    }
}
