// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <algorithm>

#import "IFFChunkTable.h"

using namespace TagLib;

namespace {

/// TagLib's own limit, past which it treats the file as invalid.
const size_t maxChunkCount = 50000;

bool isValidChunkName(const ByteVector &name) {
    return name.size() == 4 && std::none_of(name.begin(), name.end(), [](unsigned char c) { return c < 32 || c > 127; });
}

} // namespace

namespace IFFChunkTable {

const ByteVector fillerSignature("SPFK", 4);

bool read(File &file, Table &table) {
    file.seek(0);
    const ByteVector header = file.readBlock(12);
    if (header.size() < 12)
        return false;

    const ByteVector form = header.mid(0, 4);
    const ByteVector type = header.mid(8, 4);

    if (form == "FORM" && (type == "AIFF" || type == "AIFC")) {
        table.bigEndian = true;
        table.fillerID = ByteVector("FLLR", 4);
    } else if (type == "WAVE") {
        table.longForm = form == "RF64" || form == "BW64";
        if (!table.longForm && form != "RIFF")
            return false;
    } else {
        return false;
    }

    const offset_t length = file.length();
    unsigned long long dataSize64 = 0;
    offset_t offset = 12;

    while (length - offset >= 8) {
        if (table.chunks.size() >= maxChunkCount)
            return false;

        file.seek(offset);
        const ByteVector chunkHeader = file.readBlock(8);
        const ByteVector id = chunkHeader.mid(0, 4);

        if (!isValidChunkName(id))
            break;

        const unsigned int declared = chunkHeader.toUInt(4, table.bigEndian);
        const offset_t available = length - offset - 8;
        long long size = declared;

        if (table.longForm && id == "ds64" && table.chunks.empty() && declared >= 28) {
            if (const ByteVector sizes = file.readBlock(28); sizes.size() == 28) {
                table.ds64 = offset + 8;
                dataSize64 = sizes.toULongLong(8, false);
            }
        }

        if (table.longForm && id == "data" && declared == 0xFFFFFFFFu && dataSize64 > 0)
            size = dataSize64 > static_cast<unsigned long long>(available) ? available : static_cast<long long>(dataSize64);

        if (size > available)
            size = available;

        Chunk chunk { id, ByteVector(), offset, static_cast<offset_t>(size), 0, false };

        file.seek(offset + 8);
        if (id == "LIST" && size >= 4)
            chunk.listType = file.readBlock(4);
        if (id == table.fillerID && size >= 4)
            chunk.isFiller = file.readBlock(4) == fillerSignature;

        offset = chunk.end();

        if (offset & 1) {
            file.seek(offset);
            if (const ByteVector pad = file.readBlock(1); pad.size() == 1 && (pad[0] == '\0' || isValidChunkName(file.readBlock(4)))) {
                chunk.padding = 1;
                offset++;
            }
        }

        table.chunks.push_back(chunk);
    }

    table.end = offset;
    return !table.chunks.empty() && (!table.longForm || table.ds64 > 0);
}

} // namespace IFFChunkTable
