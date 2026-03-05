# SPFKMetadata

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)

A Swift audio metadata library wrapping [TagLib](https://github.com/taglib/taglib) (v2.1.1), [libsndfile](https://github.com/libsndfile/libsndfile) (v1.2.2), and Core Audio to provide unified tag reading/writing, marker parsing, and broadcast wave (BEXT) support across common audio formats.

No single framework handles all audio metadata scenarios in Swift. AVFoundation lacks write support and misses RIFF markers, BEXT chunks, and MP3 chapter frames. SPFKMetadata fills those gaps with a two-target architecture: a pure Swift layer for types and logic, and an ObjC++/C bridge for TagLib and libsndfile interop.

![SPFKMetadata-logo-03-256](https://github.com/user-attachments/assets/1ad2a41c-5f4f-458f-9488-b916d355506e)

## Platforms

- macOS 12+
- iOS 15+
- Swift 6.2, C++20

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

### MetaAudioFileDescription

Top-level struct that orchestrates parsing and saving all metadata for an audio file. Aggregates tag properties, audio format info, BEXT data, iXML, markers, and embedded artwork into a single Codable, Sendable type. Handles format-specific I/O dispatch (WAV files use the WaveFileC bridge; other formats use TagLib and AVFoundation).

### Tag Properties

The unified tag system for reading and writing audio metadata across ID3v2 and RIFF INFO formats.

- **TagKey** — 100+ case enum serving as the canonical key type, mapping to both ID3 frames and RIFF INFO tags. Supports lookup by `taglibKey`, `displayName`, `id3Frame`, and `infoFrame`.
- **TagProperties** — Main I/O struct wrapping `TagData` with load/save via TagLib. Handles reading and writing tags to MP3, WAV, AIFF, FLAC, OGG, M4A, and other formats.
- **TagPropertiesAV** — AVFoundation-based tag reader (read-only) for formats where TagLib support is limited.
- **TagData** — Container wrapping a `TagKeyDictionary` and custom tags dictionary, with merge support via `DictionaryMergeScheme` (.preserve, .replace, .combine).
- **TagSet** — Enum grouping TagKeys into logical sets (common, music, loudness, replayGain, utility, other) for UI organization.
- **ID3FrameKey** — 80+ case enum for ID3v2.4 frame identifiers (TALB, TIT2, TPE1, etc.).
- **InfoFrameKey** — 90+ case enum for RIFF INFO chunk tags (IART, INAM, ICRD, etc.).
- **TagFrameKey** — Protocol providing default implementations for `taglibKey`, `displayName`, and `init?(value:)` shared by both frame key types.

### Audio File Definitions

Types for audio format metadata, file type detection, and broadcast wave support.

- **AudioFormatProperties** — Struct holding channel count, sample rate, bit depth, bit rate, and duration with cached human-readable description strings.
- **AudioFileType+TagType** — Bidirectional mapping between `AudioFileType` and `TagFileTypeDef`, with file extension and URL-based detection.
- **BEXTDescription** — Broadcast Wave Extension (BWF) chunk wrapper supporting v0/v1/v2 fields including originator, coding history, UMID, loudness values (via `LoudnessDescription` from spfk-audio-base), and 64-bit time reference (hi/lo word assembly). Includes `validated()` for sanitizing empty fields and conversion to/from the C bridge type.
- **BEXTDescription.Key** — Enum of BEXT field keys with `OrderedDictionary` subscript for dictionary-style get/set access to all BEXT fields.
- **ImageDescription** — Embedded artwork container with CGImage, thumbnail generation, and Codable conformance (deliberately excludes full CGImage from serialization, storing only thumbnail data).
- **TagPicture+** — Extension for reading embedded artwork from files via TagLib.
- **WaveFileC+** — Swift convenience accessors on `WaveFileC` for `bextDescription`, INFO frame subscripts, and ID3 frame subscripts.

### Markers

Format-agnostic audio marker and chapter system with parsers for WAV, AIFF, MP3, M4A, FLAC, and OGG.

- **AudioMarkerDescription** — Format-agnostic marker struct with name, start/end time, color, and markerID. Codable, Comparable (by time, then name), with description/debugDescription.
- **AudioMarkerDescriptionCollection** — Ordered collection with insert, remove, update, sort, and automatic ID assignment. Deduplicates by start time on insert.
- **AudioMarkerDescriptionCollection+Parser** — Factory initializer from URL with automatic file-type dispatch to the appropriate parser.
- **ChapterParser** — AVFoundation-based chapter parsing for M4A, MP4, FLAC, and OGG via `AVAsset` timed metadata.

### SPFKMetadataC (ObjC++/C Bridge)

Low-level bridge layer exposing TagLib and libsndfile functionality to Swift through Objective-C++ classes.

| Class | Description |
|---|---|
| **TagLibBridge** | Core TagLib operations: read/write tag properties, strip tags, copy metadata between files |
| **TagFile** | File handle wrapper for TagLib with format-specific tag access |
| **ID3File** | ID3v2-specific file access with frame-level read/write and XMP support |
| **TagPicture** | Embedded artwork extraction and embedding via TagLib |
| **TagPictureRef** | CGImageRef container for artwork with UTType, managing Core Graphics reference counting across the Swift/ObjC boundary |
| **WaveFileC** | RIFF WAV file operations via libsndfile (INFO chunks, markers, BEXT) |
| **BEXTDescriptionC** | C-compatible BEXT chunk struct for bridge interop |
| **AudioMarkerUtil** | RIFF audio marker (cue point) parsing for WAV and AIFF |
| **MPEGChapterUtil** | ID3v2 CHAP frame parsing for MP3 chapter markers |
| **ChapterMarker** | Chapter marker data object for AVFoundation chapter parsing |

## Installation

The package contains two targets: **SPFKMetadata** (pure Swift) and **SPFKMetadataC** (ObjC++/C with TagLib and libsndfile).

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
| [CXXTagLib](https://github.com/ryanfrancesconi/CXXTagLib) | TagLib C++ library for audio tag reading/writing |
| [spfk-audio-base](https://github.com/ryanfrancesconi/spfk-audio-base) | Shared audio type definitions |
| [spfk-utils](https://github.com/ryanfrancesconi/spfk-utils) | Foundation utilities and extensions |
| [sndfile](https://github.com/sbooth/sndfile-binary-xcframework) | libsndfile binary xcframework |
| [ogg](https://github.com/sbooth/ogg-binary-xcframework) | Ogg container format support |
| [FLAC](https://github.com/sbooth/flac-binary-xcframework) | FLAC codec support |
| [opus](https://github.com/sbooth/opus-binary-xcframework) | Opus codec support |
| [vorbis](https://github.com/sbooth/vorbis-binary-xcframework) | Vorbis codec support |

## About

Spongefork (SPFK) is the personal software projects of [Ryan Francesconi](https://github.com/ryanfrancesconi). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2016 to 2025 he was the lead macOS developer at [Audio Design Desk](https://add.app).
