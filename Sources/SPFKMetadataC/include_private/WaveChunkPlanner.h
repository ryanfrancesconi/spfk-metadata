// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef WAVECHUNKPLANNER_H
#define WAVECHUNKPLANNER_H

#include <optional>
#include <vector>

#include <taglib/tbytevector.h>
#include <taglib/tfile.h>
#include <taglib/wavfile.h>

/// Writes a RIFF, RF64 or BW64 WAVE's chunks without ever moving `data`. A changed chunk is
/// rewritten in its slot when it fits; otherwise the slot is zeroed as `JUNK` and the chunk is
/// appended after the last one, followed by room for it to grow.
///
/// The `JUNK` the planner writes is signed, and only signed `JUNK` is reused. Every other chunk,
/// another application's `JUNK` included, keeps its bytes and place.
///
/// The file's own chunk table no longer matches the disk afterwards, so the `File` must not be
/// read or saved again.
namespace WaveChunkPlanner {

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

/// `edits`, then what `RIFF::WAV::File::save()` writes from the file's state: `bext`, iXML, ID3
/// and INFO.
bool save(TagLib::RIFF::WAV::File &file, std::vector<Edit> edits = {});

} // namespace WaveChunkPlanner

#endif
