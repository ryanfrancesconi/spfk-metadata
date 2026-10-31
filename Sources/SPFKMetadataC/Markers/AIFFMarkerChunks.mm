// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <cmath>
#include <cstdint>
#include <set>
#include <vector>

#import <taglib/aifffile.h>

#import "AIFFMarkerChunks.h"
#import "AudioMarker.h"

using namespace TagLib;

namespace {

/// The longest whole-character prefix of `name` that fits in `maxBytes` UTF-8 bytes.
NSString *prefixFitting(NSString *name, NSUInteger maxBytes) {
    NSUInteger end = 0;
    NSUInteger byteCount = 0;

    while (end < name.length) {
        const NSRange character = [name rangeOfComposedCharacterSequenceAtIndex:end];
        const NSUInteger characterBytes = [[name substringWithRange:character] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (byteCount + characterBytes > maxBytes) break;
        byteCount += characterBytes;
        end = NSMaxRange(character);
    }

    return [name substringToIndex:end];
}

/// A length byte and the name's UTF-8 bytes, padded to an even length. A name past 255 bytes keeps
/// its longest whole-character prefix, where Core Audio would store "?".
ByteVector pascalString(NSString *name) {
    NSData *utf8 = [prefixFitting(name ?: @"", 255) dataUsingEncoding:NSUTF8StringEncoding];
    const ByteVector text(static_cast<const char *>(utf8.bytes), static_cast<unsigned int>(utf8.length));

    ByteVector bytes(1, static_cast<char>(text.size()));
    bytes.append(text);

    if (bytes.size() & 1)
        bytes.append('\0');

    return bytes;
}

uint32_t framePosition(NSTimeInterval time, double sampleRate) {
    const double frames = time * sampleRate;

    if (!(frames > 0))
        return 0;

    return frames >= 4294967295.0 ? UINT32_MAX : static_cast<uint32_t>(std::floor(frames + 0.5));
}

/// File IDs are positive (1 to 32767): each marker's own ID plus one when that is free, otherwise the
/// lowest free one. Past 32767 markers the rest take 16-bit IDs Core Audio still reads.
std::vector<unsigned short> assignMarkerIDs(NSArray *markers) {
    std::vector<unsigned short> ids(markers.count);
    std::vector<bool> assigned(markers.count, false);
    std::set<unsigned int> used;

    for (NSUInteger i = 0; i < markers.count; i++) {
        const SInt32 markerID = ((AudioMarker *)markers[i]).markerID;

        if (markerID >= 0 && markerID < 32767 && used.insert(static_cast<unsigned int>(markerID) + 1).second) {
            ids[i] = static_cast<unsigned short>(markerID + 1);
            assigned[i] = true;
        }
    }

    unsigned int next = 1;

    for (NSUInteger i = 0; i < markers.count; i++) {
        if (assigned[i])
            continue;

        while (used.count(next) > 0)
            next++;

        used.insert(next);
        ids[i] = static_cast<unsigned short>(next);
    }

    return ids;
}

} // namespace

namespace AIFFMarkers {

IFFChunkPlanner::Edit edit(NSArray *markers, double sampleRate) {
    if (markers.count == 0)
        return { "MARK", ByteVector(), std::nullopt };

    const std::vector<unsigned short> ids = assignMarkerIDs(markers);
    ByteVector payload = ByteVector::fromUShort(static_cast<unsigned short>(markers.count), true);

    for (NSUInteger index = 0; index < markers.count; index++) {
        AudioMarker *marker = markers[index];
        payload.append(ByteVector::fromUShort(ids[index], true));
        payload.append(ByteVector::fromUInt(framePosition(marker.time, sampleRate), true));
        payload.append(pascalString(marker.name));
    }

    return { "MARK", ByteVector(), payload };
}

} // namespace AIFFMarkers

@implementation AIFFMarkerChunks

+ (NSArray *)adoptFileIDs:(NSArray *)markers {
    for (AudioMarker *marker in markers) {
        marker.markerID = marker.markerID > 0 ? marker.markerID - 1 : -1;
    }

    return markers;
}

+ (BOOL)isAIFF:(NSURL *)url {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:url error:nil];
    NSData *header = [handle readDataUpToLength:12 error:nil];
    [handle closeAndReturnError:nil];

    if (header.length < 12)
        return false;

    NSString *form = [[NSString alloc] initWithData:[header subdataWithRange:NSMakeRange(0, 4)] encoding:NSASCIIStringEncoding];
    NSString *type = [[NSString alloc] initWithData:[header subdataWithRange:NSMakeRange(8, 4)] encoding:NSASCIIStringEncoding];

    return [form isEqualToString:@"FORM"] && ([type isEqualToString:@"AIFF"] || [type isEqualToString:@"AIFC"]);
}

+ (BOOL)write:(NSArray *)markers to:(NSURL *)url sampleRate:(double)sampleRate {
    if (markers.count > 0 && !(sampleRate > 0))
        return false;

    RIFF::AIFF::File file(url.fileSystemRepresentation, false);

    if (!file.isValid() || file.readOnly())
        return false;

    return IFFChunkPlanner::write(file, { AIFFMarkers::edit(markers, sampleRate) });
}

@end
