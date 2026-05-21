// Star-rating read/write across all TagLib-supported formats.
//
// There is no single universal rating tag, so this bridge writes (and
// reads) the de-facto standard for each container:
//
//   • MP3 / WAV / AIFF (ID3v2)  → POPM (Popularimeter) frame, plus a
//                                 TXXX:RATING mirror for foobar/MediaMonkey.
//   • FLAC / OGG / Opus (Xiph)  → RATING (0–100) + FMPS_RATING (0.0–1.0).
//   • MP4 / M4A / ALAC          → ----:com.apple.iTunes:RATING freeform (0–100).
//   • APE / WavPack (APEv2)     → RATING (0–100).
//   • WMA (ASF)                 → WM/SharedUserRating (0–99).
//
// The API speaks a normalized 0–100 scale (matching Apple's rating
// convention: 20 per star); -1 means "no rating present".

#import <Foundation/Foundation.h>

#ifndef TAGRATING_H
#define TAGRATING_H

NS_ASSUME_NONNULL_BEGIN

@interface TagRating : NSObject

/// Read the file's rating as a normalized 0–100 value, or -1 if none.
+ (int)readNormalizedRating:(nonnull NSString *)path;

/// Write a normalized 0–100 rating to the file's format-appropriate tag.
/// A value of 0 clears the rating. Returns true on success.
+ (bool)writeNormalizedRating:(int)rating path:(nonnull NSString *)path;

@end

NS_ASSUME_NONNULL_END

#endif /* TAGRATING_H */
