// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagRatingUtil_h
#define TagRatingUtil_h

#import <Foundation/Foundation.h>
#import "TagFileType.h"

NS_ASSUME_NONNULL_BEGIN

/// Internal bridge utility for reading and writing star ratings across audio container formats.
///
/// Handles per-format storage conventions: POPM for ID3v2, RATING + FMPS_RATING for Xiph,
/// rate atom + freeform for MP4, RATING for APEv2, WM/SharedUserRating for ASF.
///
/// The `opaqueTag` parameter must be a format-specific tag pointer matching the `type` argument:
/// - ID3v2 formats (MP3, WAV, AIFF): `TagLib::ID3v2::Tag *`
/// - Xiph formats (FLAC, OGG, Opus): `TagLib::Ogg::XiphComment *`
/// - MP4 formats (M4A, MP4, AAC): `TagLib::MP4::Tag *`
@interface TagRatingUtil : NSObject

/// Reads the normalized rating (0–100) from an already-open format-specific tag.
/// Returns -1 if no rating is found.
+ (int)readFromTag:(nonnull void *)opaqueTag fileType:(TagFileTypeDef)type;

/// Writes the normalized rating (0–100) into an already-open format-specific tag.
/// A value of 0 clears any existing rating atoms.
+ (void)writeToTag:(nonnull void *)opaqueTag fileType:(TagFileTypeDef)type normalized:(int)normalized;

@end

NS_ASSUME_NONNULL_END

#endif /* TagRatingUtil_h */
