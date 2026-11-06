# SPFKMetadata

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata)](https://github.com/ryanfrancesconi/spfk-metadata/tags)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)

Reads and writes the metadata stored inside media files: tags and rating, embedded artwork,
markers and chapters, and BEXT and iXML chunks. It is built on
[TagLib](https://github.com/taglib/taglib), through
[spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib), and Core Audio, and supports MP3,
WAV, AIFF, FLAC, Ogg, Opus, MP4, M4A, Matroska and WebM.

![SPFKMetadata-logo-03-256](https://github.com/user-attachments/assets/1ad2a41c-5f4f-458f-9488-b916d355506e)

## Features

- Tags under one key vocabulary across ID3, MP4, Xiph, APE, ASF, RIFF INFO and Matroska
- Ratings of 1 to 5 stars, written in each container's own convention
- Front cover artwork, read and written without changing the file's other pictures
- Markers and chapters
- BEXT and iXML in WAV chunks and FLAC APPLICATION blocks
- A stored XMP packet, kept, replaced or removed as bytes
- `MetaAudioFileDescription` parses all of the above into one `Codable` value and saves only the
  parts marked as changed

## Usage

```swift
var tags = try TagProperties(url: url)
tags[.title] = "New Title"
try tags.save(to: url)
```

```swift
var description = try await MetaAudioFileDescription(parsing: url)
description.tagProperties[.title] = "New Title"
try description.save(dirtyFlags: [.tags])
```

## Notes

- A save writes only what its dirty flags name. A part that could not be read is never written
  back empty, and a save that left something out throws `MetadataError.incompleteSave`.
- Writing an empty marker set does not clear a file's markers. Use
  `EmbeddedAudioMarkers.removeAll(from:fileType:)`.
- A save that has to move the audio may write the file to a sibling and swap it in, which gives the
  file a new file ID.
- The value types are in
  [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base), which this package
  re-exports.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
