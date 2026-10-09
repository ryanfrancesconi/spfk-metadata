# SPFKMetadata

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata)](https://github.com/ryanfrancesconi/spfk-metadata/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata)

Reads and writes the metadata a media file stores in its own container — tags and rating, embedded artwork, markers and chapters, and the production chunks (BEXT, iXML, a stored XMP packet) — through [TagLib](https://github.com/taglib/taglib) (via [spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib)) and Core Audio, for containers AVFoundation can read but cannot write.

It is two layers:

- **Container I/O** — one Swift entry point per kind of metadata, each reading or writing that kind alone: `TagProperties`, `EmbeddedArtwork`, `EmbeddedMarkers`, `ProductionChunks`, `StoredXMPPacketWrite`.
- **The audio description** — `MetaAudioFileDescription`, which parses all of it with the file's format into one value and saves what changed.

The value types live in [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base), which has no TagLib dependency and can be used on its own. SPFKMetadata re-exports it and adds the file I/O.

SPFKMetadata serves [ShadowTag](https://spongefork.com/shadowtag/)'s metadata workflows first. It's published as a reusable package because the TagLib layer is useful in isolation, but **new features are vetted against whether they fit ShadowTag's use cases.**

![SPFKMetadata-logo-03-256](https://github.com/user-attachments/assets/1ad2a41c-5f4f-458f-9488-b916d355506e)

## Requirements

- **Platforms:** macOS 13+, iOS 16+
- **Swift:** 6.2+
- C++20

## Installation

```swift
.package(url: "https://github.com/ryanfrancesconi/spfk-metadata", from: "2.0.0")
```

```swift
import SPFKMetadata  // also brings in SPFKMetadataBase
```

## API

### The audio description

- **`MetaAudioFileDescription(parsing:)`** — tags, rating, format, BEXT, iXML, markers, artwork and video facts in one read. iXML is held as the chunk's text; a save writes BEXT and iXML only when they differ from the file's, iXML compared as text. A WAV is read in one open, its length from `fmt ` and `data`; only a compressed or malformed one is also opened with `AVAudioFile`, whose reading of it can differ. The parse makes no artwork thumbnail, whose decode can cost more than the rest of the parse; `ArtworkDescription.createThumbnail()` makes one where it is shown. A component whose reader could not open the file (tags, markers, a FLAC's BEXT and iXML) is listed in `readStatus`, which is encoded with the description; one the file does not have is read as absent, not failed.
- **`save(dirtyFlags:storedXMPPacket:)`** — writes what the flags name, then the Finder tags. Throws `FileLockError` for a locked file before writing anything. Each component of a flag is refused on its own: a part it leaves as the file has it — a component `readStatus` lists (so a failed read is never saved as an empty set), one that could not be written (the Finder tags included), or a flag the container has no writer for — is named in `MetadataError.incompleteSave(written:failures:)`, thrown after everything else is written, with the components that were. A file that could not be written at all throws `MetadataError.saveFailed`; any other error also means nothing was written.

  A save that has to move the audio — a tag or metadata block that outgrew its padding ahead of it — writes the whole file to a hidden sibling and swaps it in with `FileManager.replaceItemAt`, so an interrupted save cannot leave it half moved. The file keeps its permissions, creation date, Finder tags and extended attributes but gets a **new file ID**: a bookmark taken before the save still resolves by path, but follows a later move only once re-created. A file with another hard link, in a folder that is not writable or without room for a second copy, or on a file system other than APFS, HFS+, exFAT and FAT is saved in place. A WAV never moves its audio, so it is never swapped.
- **`reloadEmbeddedMetadata()`** — re-reads tags and, for WAV and FLAC, BEXT and iXML, after a write made behind the description's back.
- **`loadVideoTrack()`** — video-technical fields and the audio track listing, for a description decoded before those fields existed.
- **`syncUCSToIXML(category:subCategory:catID:)`** — writes UCS fields into the description's iXML USER container.

### Tags and rating

- **`TagProperties(url:)`**, **`save(to:storedXMPPacket:)`** — every tag the container stores, keyed by `TagKey`. The rating is `TagKey.rating`, as 1–5 stars.
- **`TagProperties.copyTags(from:to:)`**, **`removeAllTags(in:)`** — whole-file copy and strip.
- **`difference(fromFileAt:)`** — the tag changes a value carries relative to the file.

A tag the container stores as several values (two artists, a repeated Vorbis field, two comments in different languages) reads as one value joined with a space. Left unedited, it is written back as the file stored it; edited, it is written as the one value given. A save keeps what it does not change as stored — other applications' frames and items, an ID3v2.3 tag's version (unless the tag gains a frame v2.3 cannot hold), the case of an iTunes freeform name.

A WAV's tags are its ID3 tag, read and written as an MP3's are, and its INFO chunk is their mirror: INFO supplies only what ID3 lacks, every tag with an INFO field is written back to it, and an INFO item no tag key names reads as a custom tag under its own ID, kept, changed or removed with that tag. A WAV save writes the tags only when they differ from the file's.

### Artwork

- **`EmbeddedArtwork.read(from:)`** — the front cover, else the first picture. `nil` when there is none; throws when the file can't be opened or the picture doesn't decode.
- **`EmbeddedArtwork(contentsOf:)`** — any image `CGImageSource` reads.
- **`write(to:)`** replaces the front cover, keeping any other pictures; **`remove(from:)`** removes them all. A type ImageIO cannot write, such as WebP, is stored as JPEG.

### Markers

- **`AudioMarkerDescriptionCollection(url:)`** — reads markers or chapters, by container.
- **`EmbeddedMarkers.write(_:to:fileType:)`**, **`removeAll(from:fileType:)`** — write or clear them without touching the tags. Writing an empty array leaves the file's markers in place.

Where a container has no field for a region's end time or color, both ride in a JSON suffix on the name (`fileEncodedName`, `colorEncodedName`) and are decoded on read.

### Production chunks

- **`ProductionChunks`** — read, write and remove BEXT and iXML in WAV chunks and FLAC APPLICATION blocks. A write changes only its own chunk, and an edited BEXT keeps the stored bytes of every field left alone, reserved bytes included.
- **`WaveFileProperties(url:)`** — a WAV's format and BEXT from one open, as the parse records them.
- **`BEXTDescription(url:)`**, **`write(bextDescription:to:)`** — a WAV's BEXT alone.

### Stored XMP packet

- **`StoredXMPPacketWrite`** — keeps, replaces or removes the packet a WAV's `_PMX` chunk or an MP3's ID3v2 `PRIV` frame stores. The bytes are written as given; nothing here parses XMP. [SPFKMetadataXMP](https://github.com/ryanfrancesconi/spfk-metadata-xmp) composes it into XMP edits.

### Errors

The container I/O entry points throw `MetadataError`, which names the operation and the component (`tags`, `artwork`, `markers`, `bext`, `ixml`, `xmp`, `rating`, `finderTags`). `MetaAudioFileDescription.save` throws it too, listing what it left out, and its parse and reload throw `openFailed` for a WAV or FLAC they cannot open. A file no reader opens still throws the underlying (AVFoundation or Core Audio) error from the parse.

## Maintainers: the TagLib bridge

`SPFKMetadataC` is an internal Objective-C++ target over TagLib. The library product does not include it and the Swift module imports it `internal`, so no public declaration names a bridge type. SwiftPM still lets a dependent package import the target directly; nothing outside this package should, and a grep for `SPFKMetadataC` outside it is the check.

**Every WAV and AIFF write goes through `IFFChunkPlanner`, never `RIFF::WAV::File::save()` or `RIFF::AIFF::File::save()`**, AIFF markers included (`AIFFMarkerChunks` renders the `MARK` chunk Core Audio would write). TagLib's save removes each chunk it writes and appends it again, which moves every byte after it — the whole audio, when the metadata precedes `data` as field recorders write it. The planner rewrites a chunk in place when it fits and otherwise appends it, leaving its old slot as zeroed filler (`JUNK`, or `FLLR` in an AIFF) it signs as its own; only signed filler is reused. A new WAV or AIFF writer saves through `FileSave::save` or `IFFChunkPlanner::write`, and must not call TagLib's chunk-removing API (`strip`, `removeChunk`, `setChunkData`).

**Every other save is one `MetadataSaveSession`:** one TagLib open, each component written into it by its writer's `toFile:`/`toFileRef:` form, and one commit. The session's stream is spfk-taglib's `DeferredWriteStream`, which records every write, insertion and removal and commits once, so however many passes TagLib makes over the file — an MP4's tag and each chapter list re-render `moov` — it is written once, and a failed save leaves it untouched. A new writer for these formats takes the session's open file rather than opening its own.

**The rating does not travel through TagLib's PropertyMap.** Every container stores it differently — ID3v2 POPM (MP3, WAV, AIFF), Xiph `RATING` plus `FMPS_RATING`, the MP4 `rate` atom plus a freeform atom, APE `RATING`, ASF `WM/SharedUserRating`, a Matroska `RATING` SimpleTag — so `TagFile` pulls `RATING` out of the map and dispatches per format (`TagRating.mm`, with each container's store in `TagRatingStores.mm`). A container with no branch there reads back correctly, because its PropertyMap already carries the value, while saving a non-zero rating fails. Enabling a new container means adding a branch.

## Dependencies

| Package | Description |
|---|---|
| [spfk-metadata-base](https://github.com/ryanfrancesconi/spfk-metadata-base) | The metadata value types (no TagLib dependency) |
| [spfk-taglib](https://github.com/ryanfrancesconi/spfk-taglib) | TagLib repackaged for SwiftPM |
| [spfk-audio-base](https://github.com/ryanfrancesconi/spfk-audio-base) | Shared audio type definitions, including each format's marker storage |
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | Common extensions, type definitions and logging |
| [spfk-filesystem](https://github.com/ryanfrancesconi/spfk-filesystem) | File properties, Finder tags and lock state on a parsed description |
| [spfk-matroska](https://github.com/ryanfrancesconi/spfk-matroska) | Container reading for formats AVFoundation cannot open |
| [spfk-utils](https://github.com/ryanfrancesconi/spfk-utils) | Foundation utilities and extensions |
| [spfk-video](https://github.com/ryanfrancesconi/spfk-video) | Video track properties on a media description |
| [spfk-image](https://github.com/ryanfrancesconi/spfk-image) | Image decoding and encoding in the artwork tests (test target only) |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test fixtures, and the harness for the `spfk-metadata-bench` file-I/O bench |
| [AEXML](https://github.com/tadija/AEXML) | XML parsing for iXML |

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
