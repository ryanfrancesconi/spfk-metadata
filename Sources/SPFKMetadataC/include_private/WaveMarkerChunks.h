// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef WaveMarkerChunks_H
#define WaveMarkerChunks_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads and writes RIFF, RF64 and BW64 WAVE markers as `cue ` and `LIST`/`adtl` chunks through TagLib.
///
/// Names are written as UTF-8, and read as UTF-8 when valid, otherwise as Windows-1252 —
/// the encoding Core Audio uses, which cannot store most scripts.
@interface WaveMarkerChunks : NSObject

/// Whether the file is a RIFF, RF64 or BW64 WAVE. Wave64 is not.
+ (BOOL)isWave:(NSURL *)url;

/// Empty when the file has no markers; `nil` when it cannot be read.
+ (nullable NSArray *)read:(NSURL *)url;

/// Replaces every marker in the file. An empty array removes them.
+ (BOOL)write:(NSArray *)markers to:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END

#ifdef __cplusplus

#import <taglib/wavfile.h>

#import "IFFChunkPlanner.h"

/// A WAV file with access to its `cue ` chunk, `LIST`/`adtl` list and `_PMX` XMP chunk, which
/// TagLib does not expose.
class WaveMarkerFile : public TagLib::RIFF::WAV::File {
public:
    using TagLib::RIFF::WAV::File::File;

    /// Empty when the file has no `cue ` chunk.
    TagLib::ByteVector cueData();

    /// The first `adtl` list's sub-chunks, without the type ID. Empty when there is none.
    TagLib::ByteVector adtlData();

    /// The `_PMX` chunk's XMP packet. Empty when there is none.
    TagLib::ByteVector xmpData();

    /// `data`'s frames, for a PCM or float file with one `fmt ` and one whole `data`, a form size
    /// matching the file and a block align matching the sample size. -1 otherwise: Core Audio
    /// reads malformed files by rules of its own, such as stopping at the form size.
    long long pcmFrameCount();
};

namespace WaveMarkers {
/// Positions come from the file's own sample rate. `nil` when the file has no markers.
NSArray *_Nullable read(WaveMarkerFile &file);

/// The `cue ` and `adtl` edits that replace the file's markers; an empty array removes them.
/// `false` when the file has no sample rate.
bool render(WaveMarkerFile &file, NSArray *_Nonnull markers, std::vector<IFFChunkPlanner::Edit> &edits);

/// Replaces the file's markers on disk. `false` when the file has no sample rate.
bool write(WaveMarkerFile &file, NSArray *_Nonnull markers);
} // namespace WaveMarkers

#endif

#endif /* WaveMarkerChunks_H */
