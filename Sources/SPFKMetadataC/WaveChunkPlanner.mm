// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <algorithm>

#import <taglib/id3v2tag.h>
#import <taglib/infotag.h>

#import "WaveChunkPlanner.h"
#import "WaveChunkTable.h"

using namespace TagLib;
using WaveChunkTable::Chunk;
using WaveChunkTable::fillerSignature;

namespace {

/// Left after an appended chunk, so the next edit that grows it fits in place.
const offset_t reserveSize = 1024;

/// Bound on one zero-filling write.
const offset_t zeroBlockSize = 1 << 20;

bool matches(const Chunk &chunk, const WaveChunkPlanner::Edit &edit) {
    if (edit.id == "ID3 ")
        return chunk.id == "ID3 " || chunk.id == "id3 ";

    return chunk.id == edit.id && (edit.listType.isEmpty() || chunk.listType == edit.listType);
}

ByteVector render(const ByteVector &id, const ByteVector &payload) {
    ByteVector bytes = id + ByteVector::fromUInt(payload.size(), false) + payload;

    if (payload.size() & 1)
        bytes.append('\0');

    return bytes;
}

class Planner {
public:
    explicit Planner(File &file) : file(file) {}

    bool apply(const std::vector<WaveChunkPlanner::Edit> &edits);

private:
    File &file;
    WaveChunkTable::Table table;
    std::vector<Chunk> &chunks = table.chunks;
    /// Ranges that held an owned chunk's old content and that nothing new has covered yet.
    std::vector<std::pair<offset_t, offset_t>> stale;

    size_t indexAt(offset_t offset) const;
    void put(offset_t at, const ByteVector &bytes);
    void putFillerHeader(offset_t at, offset_t total);
    void markStale(offset_t start, offset_t end);
    void writeZeros(offset_t at, offset_t length);
    void zeroStale();
    void vacate(size_t index);
    bool isUnchanged(const Chunk &chunk, const ByteVector &payload);
    bool placeInRun(size_t start, size_t end, const WaveChunkPlanner::Edit &edit, const ByteVector &bytes);
    void place(const WaveChunkPlanner::Edit &edit, const ByteVector &bytes);
    void append(const WaveChunkPlanner::Edit &edit, const ByteVector &bytes);
    void writeFormSize();
};

size_t Planner::indexAt(offset_t offset) const {
    return static_cast<size_t>(std::find_if(chunks.begin(), chunks.end(), [offset](const Chunk &c) { return c.offset == offset; }) - chunks.begin());
}

/// Writes `bytes` and drops what they cover from the stale ranges.
void Planner::put(offset_t at, const ByteVector &bytes) {
    file.seek(at);
    file.writeBlock(bytes);

    const offset_t end = at + bytes.size();
    std::vector<std::pair<offset_t, offset_t>> remaining;

    for (const auto &[start, stop] : stale) {
        if (stop <= at || start >= end) {
            remaining.emplace_back(start, stop);
            continue;
        }
        if (start < at)
            remaining.emplace_back(start, at);
        if (stop > end)
            remaining.emplace_back(end, stop);
    }

    stale = std::move(remaining);
}

/// A filler `total` bytes long, even and at least 8; below 12 there is no room to sign it. Its
/// payload is free space already, or stale and zeroed by `zeroStale`.
void Planner::putFillerHeader(offset_t at, offset_t total) {
    ByteVector header = ByteVector("JUNK", 4) + ByteVector::fromUInt(static_cast<unsigned int>(total - 8), false);
    if (total >= 12)
        header.append(fillerSignature);

    put(at, header);
}

void Planner::markStale(offset_t start, offset_t end) {
    if (end > start)
        stale.emplace_back(start, end);
}

void Planner::writeZeros(offset_t at, offset_t length) {
    file.seek(at);

    while (length > 0) {
        const offset_t block = std::min(length, zeroBlockSize);
        file.writeBlock(ByteVector(static_cast<unsigned int>(block), '\0'));
        length -= block;
    }
}

/// Last, so old content a later placement overwrote is never zeroed first.
void Planner::zeroStale() {
    for (const auto &[start, end] : stale)
        writeZeros(start, end - start);

    stale.clear();
}

/// Renamed in place, so nothing after it moves; what it held is zeroed by `zeroStale`.
void Planner::vacate(size_t index) {
    Chunk &chunk = chunks[index];

    put(chunk.offset, ByteVector("JUNK", 4));

    if (chunk.size >= 4)
        put(chunk.offset + 8, fillerSignature);

    const offset_t signature = chunk.size >= 4 ? 4 : 0;
    markStale(chunk.offset + 8 + signature, chunk.offset + 8 + chunk.size);

    chunk.id = "JUNK";
    chunk.listType = ByteVector();
    chunk.isFiller = chunk.size >= 4;
}

bool Planner::isUnchanged(const Chunk &chunk, const ByteVector &payload) {
    if (chunk.size != static_cast<offset_t>(payload.size()))
        return false;

    file.seek(chunk.offset + 8);
    return file.readBlock(payload.size()) == payload;
}

/// Writes `bytes` over chunks `start`…`end` when they hold it with nothing left over, or with
/// enough left for a filler after it.
bool Planner::placeInRun(size_t start, size_t end, const WaveChunkPlanner::Edit &edit, const ByteVector &bytes) {
    const offset_t at = chunks[start].offset;
    const offset_t room = chunks[end].end() - at;
    const offset_t size = bytes.size();
    const offset_t rest = room - size;

    if (rest != 0 && (rest < 8 || rest & 1))
        return false;

    // The chunk being replaced is the only one in the run that is not free space already.
    for (size_t i = start; i <= end; i++) {
        if (!chunks[i].isFiller)
            markStale(chunks[i].offset + 8, chunks[i].end());
    }

    put(at, bytes);

    std::vector<Chunk> placed { { edit.id, edit.listType, at, static_cast<offset_t>(edit.payload->size()), static_cast<offset_t>(edit.payload->size() & 1), false } };

    if (rest > 0) {
        putFillerHeader(at + size, rest);
        placed.push_back({ ByteVector("JUNK", 4), ByteVector(), at + size, rest - 8, 0, rest >= 12 });
    }

    chunks.erase(chunks.begin() + start, chunks.begin() + end + 1);
    chunks.insert(chunks.begin() + start, placed.begin(), placed.end());
    return true;
}

/// Into the first run of fillers that holds it, else after the last chunk.
void Planner::place(const WaveChunkPlanner::Edit &edit, const ByteVector &bytes) {
    for (size_t start = 0; start < chunks.size(); start++) {
        if (!chunks[start].isFiller)
            continue;

        size_t end = start;
        while (end + 1 < chunks.size() && chunks[end + 1].isFiller)
            end++;

        // A run that ends the file is reused by append, which also leaves the reserve.
        if (end + 1 < chunks.size() && placeInRun(start, end, edit, bytes))
            return;

        start = end;
    }

    append(edit, bytes);
}

/// After the last chunk, reusing a run of fillers that ends the file, followed by a reserve no
/// later edit in this save may take. What is left of a reused run stays free space.
void Planner::append(const WaveChunkPlanner::Edit &edit, const ByteVector &bytes) {
    const offset_t oldEnd = table.end;
    const offset_t size = bytes.size();

    size_t first = chunks.size();
    while (first > 0 && chunks[first - 1].isFiller)
        first--;

    offset_t at = oldEnd;
    if (first < chunks.size() && chunks[first].offset % 2 == 0 && (oldEnd - chunks[first].offset) % 2 == 0) {
        at = chunks[first].offset;
        chunks.erase(chunks.begin() + first, chunks.end());
    }

    const offset_t blockStart = at;
    ByteVector block;

    // As TagLib does: the last chunk gains its missing pad byte, so this one starts even.
    if (at & 1) {
        block.append('\0');
        chunks.back().padding = 1;
        at++;
    }

    const offset_t leftover = oldEnd - (at + size);
    const offset_t spare = leftover >= reserveSize + 12 ? leftover - reserveSize : 0;
    const offset_t reserve = spare > 0 ? reserveSize : std::max(reserveSize, leftover);

    block.append(bytes);
    block.append(ByteVector("JUNK", 4) + ByteVector::fromUInt(static_cast<unsigned int>(reserve - 8), false) + fillerSignature);

    const offset_t blockEnd = blockStart + block.size();
    const offset_t end = at + size + reserve + spare;

    // Over a reused run only the block is written. What lies past the old end is new, and goes in
    // front of any bytes the walk could not reach.
    const offset_t inPlace = std::clamp<offset_t>(oldEnd - blockStart, 0, block.size());
    if (inPlace > 0)
        put(blockStart, block.mid(0, static_cast<unsigned int>(inPlace)));

    ByteVector extension = block.mid(static_cast<unsigned int>(inPlace));
    extension.resize(extension.size() + static_cast<unsigned int>(end - std::max(blockEnd, oldEnd)), '\0');

    if (!extension.isEmpty()) {
        if (oldEnd < file.length()) {
            file.insert(extension, oldEnd, 0);
        } else {
            file.seek(oldEnd);
            file.writeBlock(extension);
        }
    }

    chunks.push_back({ edit.id, edit.listType, at, static_cast<offset_t>(edit.payload->size()), static_cast<offset_t>(edit.payload->size() & 1), false });
    chunks.push_back({ ByteVector("JUNK", 4), ByteVector(), at + size, reserve - 8, 0, false });

    if (spare > 0) {
        putFillerHeader(at + size + reserve, spare);
        chunks.push_back({ ByteVector("JUNK", 4), ByteVector(), at + size + reserve, spare - 8, 0, true });
    }

    table.end = end;
}

/// As `RIFF::File::updateGlobalSize`: the size runs to the end of the last chunk; a long-form file
/// keeps the sentinel and stores it in `ds64`.
void Planner::writeFormSize() {
    const offset_t total = chunks.back().end() - 8;

    auto writeIfChanged = [this](offset_t at, const ByteVector &value) {
        file.seek(at);
        if (file.readBlock(value.size()) != value) {
            file.seek(at);
            file.writeBlock(value);
        }
    };

    if (table.longForm) {
        writeIfChanged(4, ByteVector::fromUInt(0xFFFFFFFFu, false));
        writeIfChanged(table.ds64, ByteVector::fromULongLong(static_cast<unsigned long long>(total), false));
    } else {
        writeIfChanged(4, ByteVector::fromUInt(static_cast<unsigned int>(total), false));
    }
}

bool Planner::apply(const std::vector<WaveChunkPlanner::Edit> &edits) {
    if (file.readOnly() || !WaveChunkTable::read(file, table))
        return false;

    std::vector<std::pair<const WaveChunkPlanner::Edit *, ByteVector>> unplaced;

    for (const auto &edit : edits) {
        std::vector<offset_t> existing;
        for (const Chunk &chunk : chunks) {
            if (matches(chunk, edit))
                existing.push_back(chunk.offset);
        }

        if (!edit.payload) {
            for (offset_t offset : existing)
                vacate(indexAt(offset));
            continue;
        }

        // Later duplicates go first, so the slot that stays can grow into them.
        for (size_t i = 1; i < existing.size(); i++)
            vacate(indexAt(existing[i]));

        const ByteVector bytes = render(edit.id, *edit.payload);

        if (!existing.empty()) {
            const size_t index = indexAt(existing.front());

            if (isUnchanged(chunks[index], *edit.payload))
                continue;

            size_t start = index;
            size_t end = index;
            while (start > 0 && chunks[start - 1].isFiller)
                start--;
            while (end + 1 < chunks.size() && chunks[end + 1].isFiller)
                end++;

            if (placeInRun(start, end, edit, bytes))
                continue;

            vacate(index);
        }

        unplaced.emplace_back(&edit, bytes);
    }

    // After every slot has been freed, so a chunk that grew can take another's.
    for (const auto &[edit, bytes] : unplaced)
        place(*edit, bytes);

    zeroStale();
    writeFormSize();
    return true;
}

} // namespace

namespace WaveChunkPlanner {

bool write(File &file, const std::vector<Edit> &edits) {
    return Planner(file).apply(edits);
}

bool save(RIFF::WAV::File &file, std::vector<Edit> edits) {
    if (!file.isValid())
        return false;

    auto payload = [](const ByteVector &bytes) { return bytes.isEmpty() ? std::nullopt : std::optional<ByteVector>(bytes); };

    const ID3v2::Tag *id3 = file.ID3v2Tag();
    const RIFF::Info::Tag *info = file.InfoTag();

    edits.push_back({ "bext", ByteVector(), payload(file.BEXTData()) });
    edits.push_back({ "iXML", ByteVector(), payload(file.iXMLData().data(String::UTF8)) });
    edits.push_back({ "ID3 ", ByteVector(), payload(id3 && !id3->isEmpty() ? id3->render() : ByteVector()) });
    edits.push_back({ "LIST", "INFO", payload(info && !info->isEmpty() ? info->render() : ByteVector()) });

    return write(file, edits);
}

} // namespace WaveChunkPlanner
