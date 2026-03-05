// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreImage
import Foundation
import SPFKAudioBase
import SPFKUtils

/// Top-level metadata container for an audio file.
///
/// Aggregates tag properties, audio format info, BEXT data, iXML, markers, and embedded artwork
/// into a single `Codable`, `Sendable` type. Use ``init(parsing:)`` to read all metadata from a URL,
/// and ``save(imageNeedsSave:)`` to write changes back.
///
/// WAV files are handled through the `WaveFileC` bridge (libsndfile) for BEXT, INFO, and marker support.
/// All other formats use TagLib and AVFoundation.
public struct MetaAudioFileDescription: Hashable, Sendable {
    /// The file URL this description was parsed from or will be saved to.
    public var url: URL

    /// Finder-level file properties (size, dates, tags) captured at parse time.
    public var urlProperties: URLProperties

    /// The detected audio file format, or `nil` if the format could not be determined.
    public var fileType: AudioFileType?

    /// Channel count, sample rate, bit depth, duration, and related format details.
    public var audioFormat: AudioFormatProperties?

    /// ID3 / RIFF INFO tags and custom TXXX tags read from or to be written to the file.
    public var tagProperties: TagProperties = .init()

    /// Broadcast Wave Extension (BWF) chunk data. Only present for WAV files that contain a BEXT chunk.
    public var bextDescription: BEXTDescription?

    /// Raw iXML chunk string extracted from WAV files. `nil` for non-WAV formats or files without iXML.
    public var iXMLMetadata: String?

    /// Adobe XMP metadata XML string, if present in the file's ID3 tag.
    public var xmpMetadata: String?

    /// Ordered collection of audio markers (RIFF cue points, ID3 chapters, or AVFoundation chapters).
    public var markerCollection: AudioMarkerDescriptionCollection = .init()

    /// Embedded artwork and its thumbnail. The full `CGImage` is excluded from `Codable` serialization.
    public var imageDescription: ImageDescription = .init()

    public init(
        url: URL,
        urlProperties: URLProperties? = nil,
        fileType: AudioFileType? = nil,
        audioFormat: AudioFormatProperties? = nil,
        tagProperties: TagProperties? = nil,
        bextDescription: BEXTDescription? = nil,
        xmpMetadata: String? = nil,
        iXMLMetadata: String? = nil,
        markerCollection: AudioMarkerDescriptionCollection = .init()
    ) {
        self.url = url
        self.urlProperties = urlProperties ?? URLProperties(url: url)
        self.fileType = fileType
        self.audioFormat = audioFormat

        if let tagProperties {
            self.tagProperties = tagProperties
        }

        self.bextDescription = bextDescription
        self.xmpMetadata = xmpMetadata
        self.iXMLMetadata = iXMLMetadata
        self.markerCollection = markerCollection
    }
}

extension MetaAudioFileDescription: Codable {
    enum CodingKeys: String, CodingKey {
        case url
        case urlProperties
        case fileType
        case audioFormat
        case tagProperties
        case bextDescription
        case xmpMetadata
        case iXMLMetadata
        case markerCollection
        case imageDescription
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        url = try container.decode(URL.self, forKey: .url)
        urlProperties = try container.decode(URLProperties.self, forKey: .urlProperties)
        tagProperties = try container.decode(TagProperties.self, forKey: .tagProperties)
        imageDescription = try container.decode(ImageDescription.self, forKey: .imageDescription)

        fileType = try? container.decodeIfPresent(AudioFileType.self, forKey: .fileType)
        audioFormat = try? container.decodeIfPresent(AudioFormatProperties.self, forKey: .audioFormat)

        bextDescription = try? container.decodeIfPresent(BEXTDescription.self, forKey: .bextDescription)
        xmpMetadata = try? container.decodeIfPresent(String.self, forKey: .xmpMetadata)
        iXMLMetadata = try? container.decodeIfPresent(String.self, forKey: .iXMLMetadata)

        if let markerCollection = try? container.decodeIfPresent(AudioMarkerDescriptionCollection.self, forKey: .markerCollection) {
            self.markerCollection = markerCollection
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // required
        try container.encode(url, forKey: .url)
        try container.encode(urlProperties, forKey: .urlProperties)
        try container.encode(tagProperties, forKey: .tagProperties)
        try container.encode(imageDescription, forKey: .imageDescription)

        // optionals
        try? container.encodeIfPresent(fileType, forKey: .fileType)
        try? container.encodeIfPresent(audioFormat, forKey: .audioFormat)
        try? container.encodeIfPresent(bextDescription, forKey: .bextDescription)
        try? container.encodeIfPresent(xmpMetadata, forKey: .xmpMetadata)
        try? container.encodeIfPresent(iXMLMetadata, forKey: .iXMLMetadata)

        try? container.encode(markerCollection, forKey: .markerCollection)
    }
}

// MARK: Convenience functions

extension MetaAudioFileDescription {
    /// Returns the value of a standard tag, or `nil` if not present.
    public func tag(for tagKey: TagKey) -> String? {
        tagProperties.tag(for: tagKey)
    }

    /// Returns the value of a custom (TXXX) tag by its string key, or `nil` if not present.
    public func customTag(for key: String) -> String? {
        tagProperties.customTag(for: key)
    }

    /// Sets a standard tag value. Pass `nil` to remove the tag.
    public mutating func set(tag key: TagKey, value: String) {
        tagProperties.set(tag: key, value: value)
    }

    /// Sets a custom (TXXX) tag value by its string key.
    public mutating func set(customTag key: String, value: String) {
        tagProperties.set(customTag: key, value: value)
    }

    /// Merges a BEXT key dictionary into the current BEXT description,
    /// creating a new `BEXTDescription` if one doesn't already exist.
    public mutating func merge(bext dictionary: BEXTKeyDictionary) {
        if bextDescription == nil {
            bextDescription = BEXTDescription()
        }

        for item in dictionary {
            bextDescription?[item.key] = item.value
        }
    }
}
