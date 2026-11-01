# SPFKMetadata

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata)](https://github.com/ryanfrancesconi/spfk-metadata/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)

Reads and writes the metadata a media file stores in its own container: tags and rating, embedded
artwork, markers and chapters, and the broadcast production chunks (BEXT, iXML). It is built on
[TagLib](https://github.com/taglib/taglib), through
[spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib), and Core Audio, and covers the
containers AVFoundation can read but cannot write: MP3, WAV, AIFF, FLAC, Ogg and Opus, MP4 and M4A,
Matroska and WebM.

Use it when an app's metadata edits should land in the file itself, readable by any other tool,
rather than in a sidecar or a private database. It serves
[ShadowTag](https://spongefork.com/shadowtag/)'s workflows first, and new features are weighed
against whether they fit them.

![SPFKMetadata-logo-03-256](https://github.com/user-attachments/assets/1ad2a41c-5f4f-458f-9488-b916d355506e)

## What it covers

- **Tags and rating.** Every tag a container stores, under one key vocabulary across ID3, MP4, Xiph,
  APE, ASF, RIFF INFO and Matroska. The rating is 1 to 5 stars, written in each container's own
  convention. A save keeps what it does not change as the file stored it, other applications' frames
  and items included. A WAV's tags are its ID3 tag, with INFO kept as their mirror.
- **Artwork.** The front cover, read and written without disturbing the file's other pictures. An
  unchanged picture is written back as the bytes the file stored.
- **Markers and chapters.** Read and written per container, without touching the tags.
- **Production chunks.** BEXT and iXML in WAV chunks and FLAC APPLICATION blocks. A write changes
  only its own chunk.
- **A stored XMP packet.** Kept, replaced or removed as bytes; parsing and editing XMP belongs to
  [spfk-metadata-xmp](https://github.com/ryanfrancesconi/spfk-metadata-xmp).
- **The whole description.** `MetaAudioFileDescription` parses all of the above, with the file's
  format, into one `Codable` value and saves only the parts marked as changed.

## Usage

Each kind of metadata has its own entry point, which reads or writes that kind alone:

```swift
var tags = try TagProperties(url: url)
tags[.title] = "New Title"
try tags.save(to: url)
```

Or parse everything at once and save what changed:

```swift
var description = try await MetaAudioFileDescription(parsing: url)
description.tagProperties[.title] = "New Title"
try description.save(dirtyFlags: [.tags])
```

## What a caller must know

- **A save writes only what its dirty flags name.** A part the parse could not read is never written
  back as empty, and a save that left something out throws `MetadataError.incompleteSave`, listing
  what it did write.
- **Writing an empty marker set does not clear a file's markers.** Use
  `EmbeddedAudioMarkers.removeAll(from:fileType:)`.
- **A save that must move the audio gives the file a new file ID.** When a tag outgrows its padding,
  the file is written to a hidden sibling and swapped in, so an interrupted save cannot leave it
  half written. A bookmark taken before still resolves by path. A WAV never moves its audio.

## Scope

The value types live in [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base),
which this package re-exports. XMP belongs to spfk-metadata-xmp, image XMP to spfk-metadata-image,
and reading Matroska containers to spfk-matroska.

## Maintainers: the TagLib bridge

`SPFKMetadataC` is an internal Objective-C++ target; no public declaration names a bridge type, and
nothing outside this package should import it. Three rules a new writer must follow:

- Every WAV and AIFF write goes through `IFFChunkPlanner`, never TagLib's own WAV or AIFF save,
  which removes and re-appends each chunk and so moves the audio behind it.
- Every other save is one `MetadataSaveSession`: one TagLib open, every component written into it,
  one commit.
- The rating does not travel through TagLib's PropertyMap. `TagRating.mm` dispatches it per
  container, and a container with no branch there reads a rating correctly but fails to save one.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
