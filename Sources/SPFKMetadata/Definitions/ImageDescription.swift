import CoreImage
import Foundation
import SPFKUtils

/// Container for embedded audio file artwork with thumbnail generation.
///
/// Holds the full-resolution `CGImage` (excluded from `Codable` to avoid database bloat)
/// and a small PNG thumbnail for serialization.
public struct ImageDescription: Sendable, Hashable {
    /// The full-resolution embedded artwork. Not encoded — use ``thumbnailImage`` for persistence.
    public var cgImage: CGImage?

    /// A downscaled thumbnail of the artwork, created from ``thumbnailData``.
    public private(set) var thumbnailImage: CGImage?

    /// PNG data of the thumbnail image, suitable for database storage.
    public private(set) var thumbnailData: Data?

    /// Optional text description of the image (e.g., "Front Cover").
    public var description: String?

    /// Indicates whether the artwork has been modified and needs to be written back to the file.
    public private(set) var needsSave: Bool = false

    public init() {}

    /// Generates a small PNG thumbnail from the current ``cgImage`` and stores it in ``thumbnailData``.
    public mutating func createThumbnail() async {
        guard let cgImage else {
            return
        }

        thumbnailData = await Self.createThumbnail(cgImage: cgImage)
        updateThumbnail()
    }

    /// Recreates ``thumbnailImage`` from the current ``thumbnailData``.
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
    /// Creates a PNG thumbnail of the given image, scaled to the specified size.
    /// Returns `nil` if the source image is too small (< 64px in either dimension).
    public static func createThumbnail(cgImage: CGImage, size: CGSize = .init(equal: 32)) async -> Data? {
        let task = Task<Data?, Error>(priority: .userInitiated) {
            guard cgImage.width > 64, cgImage.height > 64,
                  let rescaledImage = cgImage.scaled(to: size)
            else { return nil }

            return rescaledImage.pngRepresentation
        }

        return try? await task.value
    }

    /// Replaces the current artwork and regenerates the thumbnail.
    public mutating func update(cgImage: CGImage) async {
        self.cgImage = cgImage
        await createThumbnail()
    }
}
