# SPFKMetadata

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)

Audio metadata I/O library wrapping [TagLib](https://github.com/taglib/taglib) via [spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib) and Core Audio to provide unified tag reading/writing, marker parsing, and broadcast wave (BEXT) support across common audio formats.

The TagLib integration is provided by spfk-taglib, an independent SPM repackaging of TagLib that mirrors the upstream directory layout. The current upstream base is **TagLib 2.2.1**. spfk-taglib also includes fork additions for BEXT/iXML chunk support in WAV files and Nero-style chapter markers in MP4 files. See the [spfk-taglib README](https://github.com/ryanfrancesconi/spfk-taglib) for details.

No single framework handles all audio metadata scenarios in Swift. AVFoundation lacks write support and misses RIFF markers, BEXT chunks, iXML, and MP3 chapter frames. SPFKMetadata fills those gaps with an ObjC++/C bridge for TagLib. All WAV I/O (tags, markers, BEXT, artwork) goes through a single TagLib-backed `WaveFileC` load/save cycle.

> **Note:** Pure data types (TagKey, TagProperties, TagData, MetaAudioFileDescription, AudioMarkerDescription, BEXTDescription, etc.) have been extracted to [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base). That package has no C++/TagLib dependency and can be used standalone. SPFKMetadata re-exports these types and adds file I/O capabilities on top of them.

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

// Read markers
for marker in description.markerCollection.markerDescriptions {
    print("\(marker.name ?? "Untitled") @ \(marker.startTime)s")
}

// Copy tags between files
try TagProperties.copyTags(from: sourceURL, to: destinationURL)
```

## API Reference

Types marked with *(base)* are defined in [SPFKMetadataBase](https://github.com/ryanfrancesconi/spfk-metadata-base) and available without TagLib. Types marked with *(I/O)* are defined in this package and require the C++/ObjC bridge.

### MetaAudioFileDescription

- **MetaAudioFileDescription** *(base)* — Top-level Codable struct aggregating tag properties, audio format info, BEXT data, iXML, markers, and embedded artwork.
- **MetaAudioFileDescription+IO** *(I/O)* — Parsing initializer and `save()` method with format-specific dispatch (WAV via WaveFileC, other formats via TagLib/AVFoundation).

### Tag Properties

- **TagKey** *(base)* — 100+ case enum serving as the canonical key type, mapping to both ID3 frames and RIFF INFO tags. Supports lookup by `taglibKey`, `displayName`, `id3Frame`, and `infoFrame`.
- **TagProperties** *(base)* — Struct wrapping `TagData` with `tagLibPropertyMap` for bridge interop.
- **TagProperties+IO** *(I/O)* — Load/save via TagLib. Reading and writing tags to MP3, WAV, AIFF, FLAC, OGG, M4A, and other formats.
- **TagPropertiesAV** *(base)* — AVFoundation-based tag reader (read-only) for formats where TagLib support is limited.
- **TagData** *(base)* — Container wrapping a `TagKeyDictionary` and custom tags dictionary, with merge support via `DictionaryMergeScheme` (.preserve, .replace, .combine).
- **TagGroup** *(base)* — Enum grouping TagKeys into logical sets (common, music, loudness, replayGain, utility, other) for UI organization.
- **ID3FrameKey** *(base)* — 80+ case enum for ID3v2.4 frame identifiers (TALB, TIT2, TPE1, etc.).
- **InfoFrameKey** *(base)* — 90+ case enum for RIFF INFO chunk tags (IART, INAM, ICRD, etc.).
- **TagFrameKey** *(base)* — Protocol providing default implementations for `taglibKey`, `displayName`, and `init?(value:)` shared by both frame key types.

### Audio File Definitions

- **AudioFormatProperties** *(base)* — Struct holding channel count, sample rate, bit depth, bit rate, and duration with cached human-readable description strings.
- **AudioFormatProperties+IO** *(I/O)* — Initializer from `AVAudioFile`.
- **AudioFileType+TagType** *(I/O)* — Bidirectional mapping between `AudioFileType` and `TagFileTypeDef`, with file extension and URL-based detection.
- **BEXTDescription** *(base)* — Broadcast Wave Extension (BWF) chunk wrapper supporting v0/v1/v2 fields including originator, coding history, UMID, loudness values, and 64-bit time reference.
- **BEXTDescription+IO** *(I/O)* — Read/write BEXT chunks via `WaveFileC` (TagLib). Conversion to/from the C bridge type `BEXTDescriptionC`.
- **BEXTDescription.Key** *(base)* — Enum of BEXT field keys with `OrderedDictionary` subscript for dictionary-style get/set access.
- **ImageDescription** *(base)* — Embedded artwork container with CGImage, thumbnail generation, and Codable conformance.
- **ImageDescription+IO** *(I/O)* — Conversion to/from `TagPictureRef` for TagLib interop.
- **TagPicture+** *(I/O)* — Extension for reading embedded artwork from files via TagLib.
- **WaveFileC+** *(I/O)* — Swift convenience accessors on `WaveFileC` for `bextDescription`, INFO frame subscripts, and ID3 frame subscripts.

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
| **TagFile** | File handle wrapper for TagLib with format-specific tag access |
| **ID3File** | ID3v2-specific file access with frame-level read/write and XMP support |
| **TagPicture** | Embedded artwork extraction and embedding via TagLib |
| **TagPictureRef** | CGImageRef container for artwork with UTType, managing Core Graphics reference counting across the Swift/ObjC boundary |
| **WaveFileC** | RIFF WAV file operations via TagLib (INFO chunks, markers, BEXT) with single-load/single-save I/O |
| **BEXTDescriptionC** | EBU Tech 3285 BEXT chunk binary serializer/deserializer with initWithData:/serializedData |
| **AudioMarkerUtil** | RIFF audio marker (cue point) parsing for WAV and AIFF |
| **MPEGChapterUtil** | ID3v2 CHAP frame parsing for MP3 chapter markers |
| **ChapterMarker** | Chapter marker data object for AVFoundation chapter parsing |

## Installation

The package contains two targets: **SPFKMetadata** (pure Swift) and **SPFKMetadataC** (ObjC++/C with TagLib).

1. Add SPFKMetadata as a dependency:
   - In Xcode: **File → Swift Packages → Add Package Dependency...**
     - Enter: `https://github.com/ryanfrancesconi/SPFKMetadata`
   - In Package.swift:
     ```swift
     .package(url: "https://github.com/ryanfrancesconi/spfk-metadata", from: "0.0.1")
     ```
2. Import:
   ```swift
   import SPFKMetadata
   import SPFKMetadataC
   ```

## Dependencies

| Package | Description |
|---|---|
| [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base) | Pure metadata data types (no C++ dependency) |
| [spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib) | TagLib 2.2.1 C++ library repackaged for SPM, with BEXT/iXML and MP4 chapter extensions |
| [spfk-audio-base](https://github.com/ryanfrancesconi/spfk-audio-base) | Shared audio type definitions |
| [spfk-utils](https://github.com/ryanfrancesconi/spfk-utils) | Foundation utilities and extensions |
| [ogg](https://github.com/sbooth/ogg-binary-xcframework) | Ogg container format (TagLib link-time dependency) |
| [FLAC](https://github.com/sbooth/flac-binary-xcframework) | FLAC codec (TagLib link-time dependency) |
| [opus](https://github.com/sbooth/opus-binary-xcframework) | Opus codec (TagLib link-time dependency) |
| [vorbis](https://github.com/sbooth/vorbis-binary-xcframework) | Vorbis codec (TagLib link-time dependency) |

## About

Spongefork (SPFK) is the personal software projects of [Ryan Francesconi](https://github.com/ryanfrancesconi). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2016 to 2025 he was the lead macOS developer at [Audio Design Desk](https://add.app).
