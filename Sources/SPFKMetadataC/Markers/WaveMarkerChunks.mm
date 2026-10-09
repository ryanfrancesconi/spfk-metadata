// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <algorithm>
#include <cmath>
#include <map>
#include <set>
#include <vector>

#import <taglib/wavfile.h>

#import "AudioMarker.h"
#import "IFFChunkPlanner.h"
#import "WaveMarkerChunks.h"

using namespace TagLib;

namespace {
// dwName, dwPosition, fccChunk, dwChunkStart, dwBlockStart, dwSampleOffset
const unsigned int cuePointSize = 24;

ByteVector le32(unsigned int value) {
    return ByteVector::fromUInt(value, false);
}

NSString *decodeLabel(const ByteVector &text) {
    NSData *data = [NSData dataWithBytes:text.data() length:text.size()];

    for (NSNumber *encoding in @[ @(NSUTF8StringEncoding), @(NSWindowsCP1252StringEncoding) ]) {
        NSString *string = [[NSString alloc] initWithData:data encoding:encoding.unsignedIntegerValue];

        if (string) {
            return string;
        }
    }

    // Windows-1252 leaves five bytes undefined; Latin-1 maps every byte.
    return [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
}

/// An `adtl` sub-chunk: `labl`, `note`, `ltxt` or `file`, each opening with the cue ID it annotates.
struct SubChunk {
    ByteVector name;
    unsigned int cueID;
    /// Starting with the cue ID; no pad byte.
    ByteVector body;
};

/// Sub-chunks too short to name a cue ID are skipped.
std::vector<SubChunk> parseSubChunks(const ByteVector &adtl) {
    std::vector<SubChunk> chunks;
    unsigned int offset = 0;

    while (offset + 8 <= adtl.size()) {
        const unsigned int size = adtl.toUInt(offset + 4, false);
        const unsigned int body = offset + 8;

        if (size > adtl.size() - body) {
            break;
        }

        if (size >= 4) {
            chunks.push_back({ adtl.mid(offset, 4), adtl.toUInt(body, false), adtl.mid(body, size) });
        }

        offset = body + size + (size & 1);
    }

    return chunks;
}

/// A `labl`'s text up to its terminator.
ByteVector labelText(const SubChunk &labl) {
    ByteVector text = labl.body.mid(4);

    if (const int end = text.find('\0'); end >= 0) {
        text.resize(end);
    }

    return text;
}

/// `dwSampleOffset` keyed by cue ID.
std::map<unsigned int, unsigned int> parseCueFrames(const ByteVector &cue) {
    std::map<unsigned int, unsigned int> frames;

    if (cue.size() < 4) {
        return frames;
    }

    const unsigned int count = std::min(cue.toUInt(0, false), (cue.size() - 4) / cuePointSize);

    for (unsigned int i = 0; i < count; i++) {
        const unsigned int offset = 4 + i * cuePointSize;
        frames.emplace(cue.toUInt(offset, false), cue.toUInt(offset + 20, false));
    }

    return frames;
}

/// Each marker's own ID, so another app's `note` and `ltxt` stay on their cue; a negative or
/// repeated ID takes the lowest free one.
std::vector<unsigned int> assignCueIDs(NSArray *markers) {
    std::vector<unsigned int> ids(markers.count);
    std::vector<bool> assigned(markers.count, false);
    std::set<unsigned int> used;

    for (NSUInteger i = 0; i < markers.count; i++) {
        const SInt32 markerID = ((AudioMarker *)markers[i]).markerID;

        if (markerID >= 0 && used.insert(static_cast<unsigned int>(markerID)).second) {
            ids[i] = static_cast<unsigned int>(markerID);
            assigned[i] = true;
        }
    }

    unsigned int next = 0;

    for (NSUInteger i = 0; i < markers.count; i++) {
        if (assigned[i]) {
            continue;
        }

        while (used.count(next) > 0) {
            next++;
        }

        ids[i] = next;
        used.insert(next);
    }

    return ids;
}

void appendSubChunk(ByteVector &list, const ByteVector &name, const ByteVector &body) {
    list.append(name);
    list.append(le32(body.size()));
    list.append(body);

    if (body.size() & 1) {
        list.append('\0');
    }
}

unsigned int framePosition(NSTimeInterval time, double sampleRate) {
    const double frames = std::round(time * sampleRate);

    if (!(frames > 0)) {
        return 0;
    }

    return frames >= 0xFFFFFFFFu ? 0xFFFFFFFFu : static_cast<unsigned int>(frames);
}
} // namespace

ByteVector WaveMarkerFile::cueData() {
    for (unsigned int i = 0; i < chunkCount(); i++) {
        if (chunkName(i) == "cue ") {
            return chunkData(i);
        }
    }

    return ByteVector();
}

ByteVector WaveMarkerFile::adtlData() {
    for (unsigned int i = 0; i < chunkCount(); i++) {
        if (chunkName(i) == "LIST") {
            if (const ByteVector data = chunkData(i); data.startsWith("adtl")) {
                return data.mid(4);
            }
        }
    }

    return ByteVector();
}

ByteVector WaveMarkerFile::xmpData() {
    for (unsigned int i = 0; i < chunkCount(); i++) {
        if (chunkName(i) == "_PMX") {
            return chunkData(i);
        }
    }

    return ByteVector();
}

namespace WaveMarkers {
NSArray *read(WaveMarkerFile &file) {
    const ByteVector cue = file.cueData();

    if (cue.size() < 4) {
        return nil;
    }

    const RIFF::WAV::Properties *properties = file.audioProperties();
    const double sampleRate = properties ? properties->sampleRate() : 0;

    if (sampleRate <= 0) {
        NSLog(@"WaveMarkers: no sample rate for %s", file.name());
        return nil;
    }

    const unsigned int count = std::min(cue.toUInt(0, false), (cue.size() - 4) / cuePointSize);

    if (count == 0) {
        return nil;
    }

    std::map<unsigned int, NSString *> labels;

    for (const SubChunk &chunk : parseSubChunks(file.adtlData())) {
        if (chunk.name == "labl") {
            labels.emplace(chunk.cueID, decodeLabel(labelText(chunk)));
        }
    }

    NSMutableArray *markers = [NSMutableArray arrayWithCapacity:count];

    for (unsigned int i = 0; i < count; i++) {
        const unsigned int offset = 4 + i * cuePointSize;
        const unsigned int cueID = cue.toUInt(offset, false);

        // Core Audio positions a marker by dwSampleOffset, not dwPosition.
        const unsigned int frame = cue.toUInt(offset + 20, false);

        AudioMarker *marker = [[AudioMarker alloc] init];
        marker.markerID = static_cast<SInt32>(cueID);
        marker.time = frame / sampleRate;
        marker.sampleRate = sampleRate;

        const auto label = labels.find(cueID);
        marker.name = label != labels.end() ? label->second : [NSString stringWithFormat:@"Marker %d", i + 1];

        [markers addObject:marker];
    }

    return [markers copy];
}

bool render(WaveMarkerFile &file, NSArray *markers, std::vector<IFFChunkPlanner::Edit> &edits) {
    const RIFF::WAV::Properties *properties = file.audioProperties();
    const double sampleRate = properties ? properties->sampleRate() : 0;

    if (sampleRate <= 0) {
        NSLog(@"WaveMarkers: no sample rate for %s", file.name());
        return false;
    }

    const std::vector<unsigned int> cueIDs = assignCueIDs(markers);
    const std::map<unsigned int, unsigned int> storedFrames = parseCueFrames(file.cueData());
    const std::vector<SubChunk> stored = parseSubChunks(file.adtlData());
    std::map<unsigned int, ByteVector> storedLabels;

    for (const SubChunk &chunk : stored) {
        if (chunk.name == "labl") {
            storedLabels.emplace(chunk.cueID, labelText(chunk));
        }
    }

    ByteVector cue;
    ByteVector adtl;
    std::set<unsigned int> unchangedCueIDs;

    if (markers.count > 0) {
        cue.append(le32(static_cast<unsigned int>(markers.count)));
    }

    for (NSUInteger i = 0; i < markers.count; i++) {
        AudioMarker *marker = markers[i];
        const unsigned int cueID = cueIDs[i];
        const unsigned int frame = framePosition(marker.time, sampleRate);
        const ByteVector label = marker.name ? ByteVector(marker.name.UTF8String) : ByteVector();

        cue.append(le32(cueID));
        cue.append(le32(frame));
        cue.append(ByteVector("data"));
        cue.append(le32(0));
        cue.append(le32(0));
        cue.append(le32(frame));

        // A cue that kept its position or its label is the point another app annotated.
        const auto storedFrame = storedFrames.find(cueID);
        const auto storedLabel = storedLabels.find(cueID);

        if ((storedFrame != storedFrames.end() && storedFrame->second == frame) ||
            (storedLabel != storedLabels.end() && marker.name && storedLabel->second == label)) {
            unchangedCueIDs.insert(cueID);
        }

        if (!marker.name) {
            continue;
        }

        appendSubChunk(adtl, "labl", le32(cueID) + label + ByteVector(1, '\0'));
    }

    for (const SubChunk &chunk : stored) {
        if (chunk.name != "labl" && unchangedCueIDs.count(chunk.cueID) > 0) {
            appendSubChunk(adtl, chunk.name, chunk.body);
        }
    }

    edits.push_back({ "cue ", ByteVector(), cue.isEmpty() ? std::nullopt : std::optional<ByteVector>(cue) });
    edits.push_back({ "LIST", "adtl", adtl.isEmpty() ? std::nullopt : std::optional<ByteVector>(ByteVector("adtl") + adtl) });
    return true;
}

bool write(WaveMarkerFile &file, NSArray *markers) {
    std::vector<IFFChunkPlanner::Edit> edits;
    return render(file, markers, edits) && IFFChunkPlanner::write(file, edits);
}
} // namespace WaveMarkers

@implementation WaveMarkerChunks

+ (BOOL)isWave:(NSURL *)url {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:url error:nil];
    NSData *header = [handle readDataUpToLength:12 error:nil];
    [handle closeAndReturnError:nil];

    if (header.length < 12) {
        return NO;
    }

    const char *bytes = static_cast<const char *>(header.bytes);
    const bool isForm = memcmp(bytes, "RIFF", 4) == 0 || memcmp(bytes, "RF64", 4) == 0 || memcmp(bytes, "BW64", 4) == 0;
    return isForm && memcmp(bytes + 8, "WAVE", 4) == 0;
}

+ (NSArray *)read:(NSURL *)url {
    WaveMarkerFile file(url.fileSystemRepresentation);

    if (!file.isValid()) {
        NSLog(@"WaveMarkerChunks: Failed to open url %@", url);
        return nil;
    }

    return WaveMarkers::read(file);
}

+ (BOOL)write:(NSArray *)markers to:(NSURL *)url {
    WaveMarkerFile file(url.fileSystemRepresentation);

    if (!file.isValid() || file.readOnly()) {
        NSLog(@"WaveMarkerChunks: Failed to open url %@", url);
        return NO;
    }

    return WaveMarkers::write(file, markers);
}

@end
