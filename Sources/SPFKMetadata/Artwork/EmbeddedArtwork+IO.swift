// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC
import UniformTypeIdentifiers

extension EmbeddedArtwork {
    /// The front cover, else the first picture. Nil when the file has none; throws
    /// `MetadataError.readFailed` when the file can't be opened or its picture doesn't decode.
    public static func read(from url: URL) throws -> EmbeddedArtwork? {
        var result = TagPictureReadResult.found
        let pictureRef = TagPicture.readPath(url.path, result: &result)

        switch result {
        case .none:
            return nil

        case .found:
            guard let pictureRef else { throw MetadataError.readFailed(.artwork, url) }
            return EmbeddedArtwork(pictureRef: pictureRef)

        case .openFailed, .decodeFailed:
            throw MetadataError.readFailed(.artwork, url)

        @unknown default:
            throw MetadataError.readFailed(.artwork, url)
        }
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
