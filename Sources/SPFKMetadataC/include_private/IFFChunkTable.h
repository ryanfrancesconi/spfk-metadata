// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef IFFCHUNKTABLE_H
#define IFFCHUNKTABLE_H

#include <vector>

#include <taglib/tbytevector.h>
#include <taglib/tfile.h>

/// A RIFF, RF64 or BW64 WAVE's top-level chunks, as `IFFChunkPlanner` places them.
namespace IFFChunkTable {

/// The first payload bytes of every `JUNK` the planner writes.
extern const TagLib::ByteVector fillerSignature;

struct Chunk {
    TagLib::ByteVector id;
    TagLib::ByteVector listType;
    /// The header's position.
    TagLib::offset_t offset;
    TagLib::offset_t size;
    TagLib::offset_t padding;
    /// Signed `JUNK`: free space the planner may reuse.
    bool isFiller;

    TagLib::offset_t end() const { return offset + 8 + size + padding; }
};

struct Table {
    std::vector<Chunk> chunks;
    bool longForm = false;
    /// The `ds64` payload's position; 0 when there is none.
    TagLib::offset_t ds64 = 0;
    /// Where the walk stopped; bytes past it are not chunks TagLib can reach.
    TagLib::offset_t end = 12;
};

/// The same walk `RIFF::File::read` makes, so a chunk the planner writes is one TagLib finds.
/// False for a file that is not a WAVE, has no chunks, or is long-form without a `ds64`.
bool read(TagLib::File &file, Table &table);

} // namespace IFFChunkTable

#endif
