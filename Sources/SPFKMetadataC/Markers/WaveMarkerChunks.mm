// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <algorithm>
#include <cmath>
#include <map>

#import <taglib/wavfile.h>

#import "AudioMarker.h"
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

/// `labl` text keyed by cue ID. Other `adtl` sub-chunks (`note`, `ltxt`) are skipped.
std::map<unsigned int, NSString *> parseLabels(const ByteVector &adtl) {
    std::map<unsigned int, NSString *> labels;
    unsigned int offset = 0;

    while (offset + 8 <= adtl.size()) {
        const ByteVector name = adtl.mid(offset, 4);
        const unsigned int size = adtl.toUInt(offset + 4, false);
        const unsigned int body = offset + 8;

        if (size > adtl.size() - body) {
            break;
        }

        if (name == "labl" && size >= 4) {
            const unsigned int cueID = adtl.toUInt(body, false);
            ByteVector text = adtl.mid(body + 4, size - 4);

            if (const int end = text.find('\0'); end >= 0) {
                text.resize(end);
            }

            labels.emplace(cueID, decodeLabel(text));
        }

        offset = body + size + (size & 1);
    }

    return labels;
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

void WaveMarkerFile::replaceMarkerChunks(const ByteVector &cue, const ByteVector &adtl) {
    removeChunk("cue ");

    for (int i = static_cast<int>(chunkCount()) - 1; i >= 0; i--) {
        if (chunkName(i) == "LIST" && chunkData(i).startsWith("adtl")) {
            removeChunk(i);
        }
    }

    if (!cue.isEmpty()) {
        setChunkData("cue ", cue);
    }

    // alwaysCreate, or the first LIST — which may be INFO — is overwritten.
    if (!adtl.isEmpty()) {
        setChunkData("LIST", ByteVector("adtl") + adtl, true);
    }
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

    const std::map<unsigned int, NSString *> labels = parseLabels(file.adtlData());
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

bool write(WaveMarkerFile &file, NSArray *markers) {
    const RIFF::WAV::Properties *properties = file.audioProperties();
    const double sampleRate = properties ? properties->sampleRate() : 0;

    if (sampleRate <= 0) {
        NSLog(@"WaveMarkers: no sample rate for %s", file.name());
        return false;
    }

    ByteVector cue;
    ByteVector adtl;

    if (markers.count > 0) {
        cue.append(le32(static_cast<unsigned int>(markers.count)));
    }

    for (NSUInteger i = 0; i < markers.count; i++) {
        AudioMarker *marker = markers[i];
        const unsigned int cueID = static_cast<unsigned int>(i);
        const unsigned int frame = framePosition(marker.time, sampleRate);

        cue.append(le32(cueID));
        cue.append(le32(frame));
        cue.append(ByteVector("data"));
        cue.append(le32(0));
        cue.append(le32(0));
        cue.append(le32(frame));

        if (!marker.name) {
            continue;
        }

        const char *utf8 = marker.name.UTF8String;
        const unsigned int size = 4 + static_cast<unsigned int>(strlen(utf8)) + 1;

        adtl.append(ByteVector("labl"));
        adtl.append(le32(size));
        adtl.append(le32(cueID));
        adtl.append(ByteVector(utf8));
        adtl.append('\0');

        if (size & 1) {
            adtl.append('\0');
        }
    }

    file.replaceMarkerChunks(cue, adtl);
    return true;
}
} // namespace WaveMarkers

@implementation WaveMarkerChunks

+ (BOOL)isRIFFWave:(NSURL *)url {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:url error:nil];
    NSData *header = [handle readDataUpToLength:12 error:nil];
    [handle closeAndReturnError:nil];

    if (header.length < 12) {
        return NO;
    }

    const char *bytes = static_cast<const char *>(header.bytes);
    return memcmp(bytes, "RIFF", 4) == 0 && memcmp(bytes + 8, "WAVE", 4) == 0;
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
