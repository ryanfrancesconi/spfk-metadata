// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static const int TagRatingMinStars = 0;
static const int TagRatingMaxStars = 5;

/// Star ratings (0 unrated, 1–5) in each container's own storage: ID3v2 POPM (MP3, WAV, AIFF), Xiph
/// RATING + FMPS_RATING, MP4 `rate` + freeform atom, APE RATING, ASF `WM/SharedUserRating`, Matroska
/// RATING.
///
/// Each method opens the file itself. `TagFile` and `WaveFileC` already carry the rating as the
/// dictionary's `"RATING"` key, which is what `TagProperties` reads; prefer that.
@interface TagRating : NSObject

/// 0–5, or -1 when nothing is stored, the container has no rating, or the file can't be opened.
+ (int)read:(nonnull NSString *)path;

/// Clamped to 0–5; 0 clears the rating.
+ (BOOL)write:(int)stars toPath:(nonnull NSString *)path;

@end

NS_ASSUME_NONNULL_END

