// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef IFFCHUNKPLANNER_H
#define IFFCHUNKPLANNER_H

#include <optional>
#include <vector>

#include <taglib/tbytevector.h>
#include <taglib/tfile.h>
#include <taglib/aifffile.h>
#include <taglib/wavfile.h>

/// Writes a RIFF, RF64 or BW64 WAVE's chunks without ever moving `data`, or an AIFF's without
/// moving `SSND`. A changed chunk is rewritten in its slot when it fits; otherwise the slot is
/// zeroed as filler (`JUNK`, or `FLLR` in an AIFF) and the chunk is appended after the last one,
/// followed by room for it to grow.
///
/// The filler the planner writes is signed, and only signed filler is reused. Every other chunk,
/// another application's filler included, keeps its bytes and place.
///
/// The file's own chunk table no longer matches the disk afterwards, so the `File` must not be
/// read or saved again.
namespace IFFChunkPlanner {

struct Edit {
    /// `bext`, `ID3 `, `LIST`, …
    TagLib::ByteVector id;
    /// A `LIST`'s type (`INFO`, `adtl`); empty for any other chunk.
    TagLib::ByteVector listType;
    /// The new payload, a `LIST`'s type included; `nullopt` removes the chunk.
    std::optional<TagLib::ByteVector> payload;
};

/// Applies `edits` and nothing else. False when the file is read-only or not a WAVE the planner
/// can walk, before anything is written.
bool write(TagLib::File &file, const std::vector<Edit> &edits);

/// The chunks a WAV `save` renders from the file's state.
struct WaveChunks {
    bool bext = true;
    bool iXML = true;
    /// In the version it was read as (`FileSave::id3Version`).
    bool id3 = true;
    bool info = true;
};

/// `edits`, then what `RIFF::WAV::File::save()` writes from the file's state, limited to `chunks`.
bool save(TagLib::RIFF::WAV::File &file, std::vector<Edit> edits = {}, WaveChunks chunks = {});

/// `edits`, then what `RIFF::AIFF::File::save()` writes from the file's state: the ID3v2.4 tag.
bool save(TagLib::RIFF::AIFF::File &file, std::vector<Edit> edits = {});

} // namespace IFFChunkPlanner

#endif
