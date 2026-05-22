// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagRatingUtil_h
#define TagRatingUtil_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads and writes normalized star ratings (0–100) for all supported audio container formats.
///
/// Each call opens its own TagLib `FileRef`, performs the format-specific frame operation,
/// and closes it — keeping rating entirely separate from the generic tag dictionary pipeline.
///
/// Format storage conventions:
/// - **ID3v2** (MP3, WAV, AIFF): POPM (Popularimeter) frame, WMP email/byte-bucket scale
/// - **Xiph** (FLAC, OGG Vorbis, Opus): RATING integer field + FMPS_RATING float field
/// - **MP4** (M4A, MP4, AAC): `rate` integer atom + `----:com.apple.iTunes:RATING` freeform atom
@interface TagRatingUtil : NSObject

/// Reads the normalized rating (0–100) from the audio file at the given path.
/// Returns -1 if no rating is stored or the format is unsupported.
+ (int)readRating:(nonnull NSString *)path;

/// Writes the normalized rating (0–100) to the audio file at the given path.
/// Pass 0 to clear any existing rating. Returns YES on success.
+ (BOOL)writeRating:(int)normalized toPath:(nonnull NSString *)path;

@end

NS_ASSUME_NONNULL_END

#endif /* TagRatingUtil_h */
