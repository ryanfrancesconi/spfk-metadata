// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef AIFFMarkerChunks_H
#define AIFFMarkerChunks_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Writes AIFF and AIFF-C markers as a `MARK` chunk through `IFFChunkPlanner`, so the sound data
/// never moves and no other chunk is touched. The bytes are Core Audio's: IDs from each marker's
/// index, positions in frames rounded half up and clamped at 0, names as UTF-8 Pascal strings. A
/// name longer than 255 bytes keeps its longest whole-character prefix. Reading stays with Core Audio.
@interface AIFFMarkerChunks : NSObject

/// Whether the file is an AIFF or AIFF-C.
+ (BOOL)isAIFF:(NSURL *)url;

/// Replaces every marker, positions converted at `sampleRate`. An empty array removes the `MARK`
/// chunk.
+ (BOOL)write:(NSArray *)markers to:(NSURL *)url sampleRate:(double)sampleRate;

@end

NS_ASSUME_NONNULL_END

#ifdef __cplusplus

#import "IFFChunkPlanner.h"

namespace AIFFMarkers {
/// The edit that replaces the file's `MARK` chunk; an empty array removes it.
IFFChunkPlanner::Edit edit(NSArray *_Nonnull markers, double sampleRate);
}

#endif

#endif
