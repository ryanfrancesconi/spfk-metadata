// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

extension SaveKind {
    struct EntryPointFailed: Error {
        let kind: SaveKind
    }

    /// Runs an E kind against `description`'s file, reading what it edits from `description`;
    /// false for any other kind.
    func runEntryPoint(on description: MetaAudioFileDescription, row: SafetyNetRow) throws -> Bool {
        let url = description.url
        let succeeded: Bool

        switch self {
        case .e1:
            try TagProperties(url: url).save(to: url)
            succeeded = true

        case .e2:
            var properties = try TagProperties(url: url)
            properties[.title] = SafetyNetEdit.title
            properties.data.set(customTag: SafetyNetSetup.customTagKey, value: SafetyNetEdit.customTagValue)
            try properties.save(to: url)
            succeeded = true

        case .e3:
            // Typed as conversion's `TagPictureRef.parsing(url:)` reads a source's front cover.
            let picture = try #require(TagPictureRef(url: TestBundleResources.shared.songbird, pictureDescription: "", pictureType: "Front Cover"))
            succeeded = TagPicture.write(picture, path: url.path)

        case .e4:
            succeeded = TagPicture.write(nil, path: url.path)

        case .e5:
            succeeded = Self.writeMarkersAsConversionDoes(SafetyNetEdit.markers, to: url, fileType: row.fileType)

        case .e6:
            var bext = try #require(description.bextDescription)
            bext.sequenceDescription = SafetyNetEdit.bextSequenceDescription
            let file = WaveFileC(path: url.path)
            guard file.load() else { throw EntryPointFailed(kind: self) }
            file.bextDescriptionC = bext.bextDescriptionC
            file.markersNeedsSave = false
            file.imageNeedsSave = false
            succeeded = file.save()

        case .e7:
            let file = WaveFileC(path: url.path)
            guard file.load() else { throw EntryPointFailed(kind: self) }
            file.iXML = try Self.editedIXML(description)
            file.markersNeedsSave = false
            file.imageNeedsSave = false
            succeeded = file.save()

        case .e8:
            var bext = try #require(description.bextDescription)
            bext.sequenceDescription = SafetyNetEdit.bextSequenceDescription
            let file = FlacFileC(path: url.path)
            guard file.load() else { throw EntryPointFailed(kind: self) }
            file.bextDescription = bext
            succeeded = file.save()

        case .e9:
            let file = FlacFileC(path: url.path)
            guard file.load() else { throw EntryPointFailed(kind: self) }
            file.iXML = try Self.editedIXML(description)
            succeeded = file.save()

        default:
            return false
        }

        guard succeeded else { throw EntryPointFailed(kind: self) }
        return true
    }

    private static func editedIXML(_ description: MetaAudioFileDescription) throws -> String {
        let iXML = try #require(description.iXMLMetadata)
        try #require(iXML.contains(SafetyNetSetup.iXMLProject))
        return iXML.replacingOccurrences(of: SafetyNetSetup.iXMLProject, with: SafetyNetEdit.iXMLProject)
    }

    /// `AudioFormatConverter.writeMarkers`' dispatch, which `spfk-metadata`'s tests cannot import.
    private static func writeMarkersAsConversionDoes(_ markers: [AudioMarkerDescription], to url: URL, fileType: AudioFileType) -> Bool {
        switch fileType {
        case .wav, .aiff, .aifc:
            AudioMarkerUtil.write(markers.enumerated().map { $1.audioMarker(markerID: $0, fileType: fileType) }, to: url)
        case .mp3:
            MPEGChapterUtil.write(markers.map(\.colorEncodedChapterMarker), to: url.path)
        case .flac, .ogg, .opus:
            XiphChapterUtil.write(markers.map(\.colorEncodedChapterMarker), to: url.path)
        case .m4a, .mp4, .m4b, .mov, .m4v:
            MP4ChapterUtil.write(markers.map(\.fileEncodedChapterMarker), to: url.path)
        default:
            false
        }
    }
}
