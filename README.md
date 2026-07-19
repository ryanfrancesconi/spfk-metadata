# SPFKMetadata

[![CI](https://img.shields.io/github/actions/workflow/status/ryanfrancesconi/spfk-metadata/ci.yml?branch=development)](https://github.com/ryanfrancesconi/spfk-metadata/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata)](https://github.com/ryanfrancesconi/spfk-metadata/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)

Audio metadata I/O library wrapping [TagLib](https://github.com/taglib/taglib) via [spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib) and Core Audio to provide unified tag reading/writing, marker parsing, embedded artwork, and broadcast wave (BEXT) support across common audio formats. AVFoundation alone lacks write support and misses RIFF markers, BEXT chunks, iXML, and chapter frames — SPFKMetadata fills those gaps with an ObjC++/C bridge.

> **Note:** Pure data types (TagKey, TagProperties, MetaAudioFileDescription, AudioMarkerDescription, BEXTDescription, etc.) have been extracted to [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base). That package has no C++/TagLib dependency and can be used standalone. SPFKMetadata re-exports these types and adds file I/O on top.

SPFKMetadata serves [ShadowTag](https://spongefork.com/shadowtag/)'s specific metadata workflows first. It's published as a reusable package because the C++/TagLib bridge is genuinely useful in isolation, but **new features are vetted against whether they fit ShadowTag's use cases.**

![SPFKMetadata-logo-03-256](https://github.com/user-attachments/assets/1ad2a41c-5f4f-458f-9488-b916d355506e)

## Requirements

- **Platforms:** macOS 13+, iOS 16+
- **Swift:** 6.2+
- C++20

## Usage

```swift
import SPFKMetadata

// Parse all metadata from an audio file
var description = try await MetaAudioFileDescription(parsing: url)

// Read tags
let title = description.tag(for: .title)
let artist = description.tag(for: .artist)
let bpm = description.tempo

// Write tags
description.set(tag: .title, value: "New Title")
description.set(tag: .genre, value: "Electronic")
description.set(customTag: "MY_CUSTOM_TAG", value: "custom value")
try description.save()

// Read BEXT chunk (WAV only)
if let bext = description.bextDescription {
    print(bext[.originator])
    print(bext.timeReferenceString)
    print(bext.loudnessDescription)
}

// Read iXML metadata (WAV/FLAC)
if let ixml = description.ixmlMetadata {
    print(ixml.scene ?? "")
    print(ixml.take ?? "")
    // Descriptor-based access
    let descriptor = IXMLTagDescriptor.descriptor(forIdentifier: "scene")
    print(ixml.value(for: descriptor) ?? "")
}

// Read markers
for marker in description.markerCollection.markerDescriptions {
    print("\(marker.name ?? "Untitled") @ \(marker.startTime)s")
}

// Read embedded artwork
if let image = description.imageDescription {
    let cgImage = image.cgImage
    print("\(cgImage.width)×\(cgImage.height)")
}

// Write embedded artwork
if let pictureRef = TagPictureRef(
    url: artworkURL,
    pictureDescription: "Front Cover",
    pictureType: "Front Cover"
) {
    description.imageDescription = ImageDescription(pictureRef: pictureRef)
    try description.save()
}

// Remove embedded artwork
description.imageDescription = nil
try description.save()

// Read/write star rating (0 = unrated, 1–5 stars) — preferred path
let rating = description.tag(for: .rating)    // "0"–"5" string, or nil
description.set(tag: .rating, value: "4")
try description.save()

// Standalone path-based access (opens its own FileRef — use for isolated rating I/O)
let stars = TagRating.read(url.path)          // -1 on error, 0 if unrated
TagRating.write(4, toPath: url.path)          // write 4 stars
TagRating.write(0, toPath: url.path)          // clear rating

// Copy tags between files
try TagProperties.copyTags(from: sourceURL, to: destinationURL)
```

## API Reference

Types marked with *(base)* are defined in [SPFKMetadataBase](https://github.com/ryanfrancesconi/spfk-metadata-base) and available without TagLib. Types marked with *(I/O)* are defined in this package and require the C++/ObjC bridge.

### MetaAudioFileDescription

- **MetaAudioFileDescription** *(base)* — Top-level Codable struct aggregating tag properties, audio format info, BEXT data, iXML, markers, and embedded artwork.
- **MetaAudioFileDescription+IO** *(I/O)* — Parsing initializer and `save()` method with format-specific dispatch (WAV via WaveFileC, FLAC via FlacFileC, other formats via TagLib/AVFoundation).

### Tag Properties

- **TagKey** *(base)* — 100+ case enum serving as the canonical key type, mapping to both ID3 frames and RIFF INFO tags.
- **TagProperties** *(base)* — Struct wrapping `TagData` with `tagLibPropertyMap` for bridge interop.
- **TagProperties+IO** *(I/O)* — Load/save via TagLib across MP3, WAV, AIFF, FLAC, OGG, M4A, and other formats.
- **TagPropertiesAV** *(base)* — AVFoundation-based tag reader (read-only) for formats where TagLib support is limited.
- **TagData** *(base)* — Container wrapping a `TagKeyDictionary` and custom tags dictionary, with merge support via `DictionaryMergeScheme` (.preserve, .replace, .combine).
- **TagGroup** *(base)* — Enum grouping TagKeys into logical sets for UI organization.
- **ID3FrameKey** *(base)* — 80+ case enum for ID3v2.4 frame identifiers.
- **InfoFrameKey** *(base)* — 90+ case enum for RIFF INFO chunk tags.
- **TagFrameKey** *(base)* — Protocol providing default implementations for `taglibKey`, `displayName`, and `init?(value:)` shared by both frame key types.

### Audio File Definitions

- **AudioFormatProperties** *(base)* — Struct holding channel count, sample rate, bit depth, bit rate, and duration.
- **AudioFormatProperties+IO** *(I/O)* — Initializer from `AVAudioFile`.
- **AudioFileType+TagType** *(I/O)* — Bidirectional mapping between `AudioFileType` and `TagFileTypeDef`, with file extension, header inspection, and URL-based detection.
- **BEXTDescription** *(base)* — Broadcast Wave Extension (BWF) chunk wrapper supporting v0/v1/v2 fields including originator, coding history, UMID, loudness values, and 64-bit time reference.
- **BEXTDescription+IO** *(I/O)* — Read/write BEXT chunks via `WaveFileC` (TagLib). Conversion to/from the C bridge type `BEXTDescriptionC`.
- **BEXTDescription+IXML** *(I/O)* — Fallback BEXT construction from an iXML document for files that embed BEXT data in an iXML APPLICATION block rather than a binary BEXT chunk.
- **BEXTDescription.Key** *(base)* — Enum of BEXT field keys with `OrderedDictionary` subscript for dictionary-style get/set access.
- **ImageDescription** *(base)* — Embedded artwork container with CGImage, thumbnail generation, and Codable conformance.
- **ImageDescription+IO** *(I/O)* — Conversion to/from `TagPictureRef` for TagLib interop.
- **WaveFileC+** *(I/O)* — Swift convenience accessors on `WaveFileC` for `bextDescription`, INFO frame subscripts, and ID3 frame subscripts.
- **FlacFileC+** *(I/O)* — Swift convenience accessors on `FlacFileC` for `bextDescription` read/write via FLAC APPLICATION blocks.

### iXML (BWFXML)

Full structured support for the [iXML](http://www.ixml.info) (BWFXML) specification embedded in WAV and FLAC APPLICATION blocks. 56+ fields across 8 sections with round-trip XML fidelity.

- **IXMLMetadata** *(I/O)* — Core iXML document model covering production, speed, track list, loudness, BEXT mirror, history, user, ASWG, and location containers. Construct via `init(xml:)` to parse from an XML string, or `init(from:)` to build from a `MetaAudioFileDescription`. Generate XML via `.xml`.
- **IXMLElement** *(I/O)* — Type-safe enum of iXML element names with an `AEXMLElement` subscript extension for safe child access.
- **IXMLTagDescriptor** *(I/O)* — Field descriptor for UI editors: display name, section, XML tag, read-only status, and edit style (text/boolean/numeric/date). Registry of all 56+ fields queryable by section or identifier.
- **IXMLSection** *(I/O)* — Enum grouping iXML fields into UI sections: core, user, aswg, bext, speed, history, location, loudness.
- **IXMLMetadata+Accessors** *(I/O)* — Descriptor-based read/write via `value(for:)` and `setValue(_:for:)`, enabling generic UI editors to access any iXML field without switch statements.
- **IXMLUserFields** *(I/O)* — Structured model for the 37-field Soundminer USER container. Parsed from and serialized back to the USER XML element with round-trip preservation of unknown fields.
- **UCSUserFields** *(I/O)* — UCS (Universal Category System) fields extracted from the USER element: CATEGORY, SUBCATEGORY, CATID. Auto-generates CATEGORYFULL on write.
- **IXMLASWGFields** *(I/O)* — 14-field structured model for the ASWG (Audio Software Group) container per the ASWG iXML spec.

### Markers

- **AudioMarkerDescription** *(base)* — Format-agnostic marker struct with name, start/end time, color, and markerID. Codable, Comparable (by time, then name).
- **AudioMarkerDescriptionCollection** *(base)* — Ordered collection with insert, remove, update, sort, and automatic ID assignment.
- **AudioMarkerDescription+IO** *(I/O)* — Creates markers from Core Audio RIFF cue points.
- **AudioMarkerDescriptionCollection+Parser** *(I/O)* — Factory initializer from URL with automatic file-type dispatch to the appropriate parser.
- **ChapterParser** *(I/O)* — AVFoundation-based chapter parsing for M4A, MP4, FLAC, and OGG via `AVAsset` timed metadata.

### SPFKMetadataC (ObjC++/C Bridge)

Low-level bridge layer exposing TagLib functionality to Swift through Objective-C++ classes.

| Class | Description |
|---|---|
| **TagLibBridge** | Core TagLib operations: read/write tag properties, strip tags, copy metadata between files |
| **TagRating** | Reads and writes 5-star ratings (0–5, where 0 = unrated) across all supported container formats. Integrated into the tag dictionary pipeline: `TagFile` and `WaveFileC` call `TagRatingReadFromFile`/`TagRatingWriteToFile` while their `FileRef` is already open, injecting rating as the `"RATING"` dictionary key. In Swift it surfaces as `TagKey.rating` in `TagProperties`/`MetaAudioFileDescription`. A standalone `+read:`/`+write:toPath:` interface is also available for isolated access. Format conventions: ID3v2 (MP3/WAV/AIFF) → POPM Popularimeter (WMP canonical bytes); Xiph (FLAC/OGG) → `RATING` integer field + `FMPS_RATING` float field; MP4 (M4A) → `rate` atom + `----:com.apple.iTunes:RATING` freeform; APE → `RATING` integer; ASF (WMA) → `WM/SharedUserRating`. |
| **TagFile** | File handle wrapper for TagLib with format-specific tag access |
| **ID3File** | ID3v2-specific file access with frame-level read/write and XMP support |
| **TagPicture** | Embedded artwork extraction and embedding via TagLib. Reads using `CGImageSource` (JPEG, PNG, WebP, HEIC, TIFF, GIF, etc.). Writes using `CGImageDestination`; formats that cannot be written (e.g. WebP) are automatically transcoded to JPEG before embedding. For FLAC, routes through `FileRef::setComplexProperties` to write native PICTURE blocks and migrates legacy XiphComment `METADATA_BLOCK_PICTURE` entries on write. |
| **TagPictureRef** | CGImageRef container for artwork with UTType, managing Core Graphics reference counting across the Swift/ObjC boundary |
| **WaveFileC** | RIFF WAV file operations via TagLib (INFO chunks, markers, BEXT) with single-load/single-save I/O |
| **FlacFileC** | FLAC file operations via TagLib (Xiph tags, APPLICATION blocks for BEXT and iXML) |
| **BEXTDescriptionC** | EBU Tech 3285 BEXT chunk binary serializer/deserializer with initWithData:/serializedData |
| **AudioMarkerUtil** | RIFF audio marker (cue point) parsing for WAV and AIFF |
| **MPEGChapterUtil** | ID3v2 CHAP frame parsing for MP3 chapter markers |
| **XiphChapterUtil** | TagLib-based Vorbis comment chapter read/write for FLAC, OGG Vorbis, and OGG Opus |
| **MP4ChapterUtil** | Nero-style MP4/M4A chapter marker read/write via `chpl` atom |
| **ChapterMarker** | Chapter marker data object for AVFoundation chapter parsing |

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/ryanfrancesconi/spfk-metadata", from: "0.0.1")
```

Then import:

```swift
import SPFKMetadata          // Swift API + re-exported SPFKMetadataBase types
import SPFKMetadataC         // only needed for direct ObjC bridge access
```

## Dependencies

| Package | Description |
|---|---|
| [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base) | Pure metadata data types (no C++ dependency) |
| [spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib) | TagLib C++ library repackaged for SPM |
| [spfk-audio-base](https://github.com/ryanfrancesconi/spfk-audio-base) | Shared audio type definitions |
| [spfk-utils](https://github.com/ryanfrancesconi/spfk-utils) | Foundation utilities and extensions |
| [ogg](https://github.com/sbooth/ogg-binary-xcframework) | Ogg container format (TagLib link-time dependency) |
| [FLAC](https://github.com/sbooth/flac-binary-xcframework) | FLAC codec (TagLib link-time dependency) |
| [opus](https://github.com/sbooth/opus-binary-xcframework) | Opus codec (TagLib link-time dependency) |
| [vorbis](https://github.com/sbooth/vorbis-binary-xcframework) | Vorbis codec (TagLib link-time dependency) |

## About

Spongefork (SPFK) is the personal software projects of [Ryan Francesconi](https://github.com/ryanfrancesconi). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2016 to 2025 he was the lead macOS developer at [Audio Design Desk](https://add.app).
