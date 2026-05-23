// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads and writes 5-star ratings (0–5) for all supported audio container formats.
///
/// Each call opens its own TagLib `FileRef`, performs the format-specific frame operation,
/// and closes it — keeping rating entirely separate from the generic tag dictionary pipeline.
///
/// The public API works exclusively in star counts (0 = unrated, 1–5 = rated).
/// All format-specific encodings (POPM bytes, normalized 0–100 integers, FMPS_RATING floats)
/// are internal implementation details handled by this class.
///
/// Format storage conventions:
/// - **ID3v2** (MP3, WAV, AIFF): POPM (Popularimeter) frame with WMP canonical byte values
/// - **Xiph** (FLAC, OGG Vorbis, Opus): RATING integer field (normalized) + FMPS_RATING float field
/// - **MP4** (M4A, MP4, AAC): `rate` integer atom + `----:com.apple.iTunes:RATING` freeform atom
/// - **APE tag** (Monkey's Audio, WavPack): RATING integer field
/// - **ASF** (WMA): `WM/SharedUserRating` unsigned integer (0–99 scale)
static const int TagRatingMinStars = 0;
static const int TagRatingMaxStars = 5;

@interface TagRating : NSObject

/// Reads the star rating (0–5) from the audio file at the given path.
/// Returns 0 if the file has no rating stored, or -1 on error or unsupported format.
+ (int)read:(nonnull NSString *)path;

/// Writes the star rating (0–5) to the audio file at the given path.
/// Pass 0 to clear any existing rating. Returns YES on success.
+ (BOOL)write:(int)stars toPath:(nonnull NSString *)path;

@end

NS_ASSUME_NONNULL_END

