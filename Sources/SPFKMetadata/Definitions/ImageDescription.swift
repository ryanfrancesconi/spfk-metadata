import CoreImage
import Foundation
import SPFKMetadataC
import SPFKUtils

public struct ImageDescription: Sendable, Hashable {
    public var cgImage: CGImage?
    public private(set) var thumbnailImage: CGImage?
    public private(set) var thumbnailData: Data?
    public var description: String?

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

    public private(set) var needsSave: Bool = false

    public init() {}

    public mutating func createThumbnail() async {
        guard let cgImage else {
            return
        }

        thumbnailData = await Self.createThumbnail(cgImage: cgImage)
        updateThumbnail()
    }

    public mutating func updateThumbnail() {
        if let thumbnailData {
            thumbnailImage = try? CGImage.create(from: thumbnailData)
        }
    }
}

// MARK: deliberately not encoding CGImage due to size stored in database

extension ImageDescription: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.thumbnailData == rhs.thumbnailData &&
            lhs.description == rhs.description
    }
}

extension ImageDescription: Codable {
    enum CodingKeys: String, CodingKey {
        case thumbnailData
        case description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        thumbnailData = try? container.decodeIfPresent(Data.self, forKey: .thumbnailData)
        description = try? container.decodeIfPresent(String.self, forKey: .description)

        updateThumbnail()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try? container.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
        try? container.encodeIfPresent(description, forKey: .description)
    }
}

extension ImageDescription {
    public static func createThumbnail(cgImage: CGImage, size: CGSize = .init(equal: 32)) async -> Data? {
        let task = Task<Data?, Error>(priority: .userInitiated) {
            guard cgImage.width > 64, cgImage.height > 64,
                  let rescaledImage = cgImage.scaled(to: size)
            else { return nil }

            return rescaledImage.pngRepresentation
        }

        return try? await task.value
    }

    public mutating func update(cgImage: CGImage) async {
        self.cgImage = cgImage
        await createThumbnail()
    }
}
