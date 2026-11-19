// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreGraphics
import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC
import UniformTypeIdentifiers

extension EmbeddedArtwork {
    /// The front cover, else the first picture. Nil when the file has none; throws
    /// `MetadataError.readFailed` when the file can't be opened or its picture doesn't decode.
    public static func read(from url: URL) throws -> EmbeddedArtwork? {
        try TagPictureRef.reading(url: url).map(EmbeddedArtwork.init(pictureRef:))
    }

    /// The type a new picture of `cgImage` is embedded in, only ever JPEG or PNG: `declaredType`, else
    /// the image's own source type, when it is one of those; otherwise PNG for an image with alpha
    /// and JPEG for one without.
    public static func embeddedType(of cgImage: CGImage, declaredType: UTType? = nil) -> UTType {
        let declared = declaredType ?? (cgImage.utType as String?).flatMap { UTType($0) }
        return TagPictureRef.embeddedType(for: cgImage, declaredType: declared)
    }

    /// Any image file `CGImageSource` reads. Nil when it can't.
    public init?(contentsOf imageFile: URL, pictureDescription: String = "", pictureType: String = "") {
        guard let pictureRef = TagPictureRef(
            url: imageFile,
            pictureDescription: pictureDescription,
            pictureType: pictureType
        ) else { return nil }

        self.init(pictureRef: pictureRef)
    }

    /// Replaces the file's front cover, else its first picture, keeping any others.
    public func write(to url: URL) throws {
        guard TagPicture.write(pictureRef, path: url.path) else {
            throw MetadataError.writeFailed(.artwork, url)
        }
    }

    /// Removes every picture in the file.
    public static func remove(from url: URL) throws {
        guard TagPicture.write(nil, path: url.path) else {
            throw MetadataError.removeFailed(.artwork, url)
        }
    }
}

extension EmbeddedArtwork {
    init(pictureRef: TagPictureRef) {
        self.init(
            cgImage: pictureRef.cgImage,
            utType: pictureRef.utType,
            pictureDescription: pictureRef.pictureDescription ?? "",
            pictureType: pictureRef.pictureType ?? ""
        )
    }

    var pictureRef: TagPictureRef {
        TagPictureRef(
            image: cgImage,
            utType: utType,
            pictureDescription: pictureDescription,
            pictureType: pictureType
        )
    }
}
