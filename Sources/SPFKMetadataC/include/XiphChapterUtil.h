// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TagLib-based utility for reading, writing, and removing Vorbis comment chapter markers
/// in FLAC, OGG Vorbis, and OGG Opus files.
///
/// Chapters are stored as XiphComment fields using the standard convention:
/// `CHAPTER000=HH:MM:SS.mmm`, `CHAPTER000NAME=Chapter Title`.
///
/// Operates via TagLib's `FLAC::File`, `Vorbis::File`, and `Ogg::Opus::File` APIs.
/// Chapter data is represented as `ChapterMarker` objects with start time, end time, and name.
@interface XiphChapterUtil : NSObject

/// Reads all Vorbis comment chapter markers from the file at the given path.
/// @param path Absolute path to a FLAC, OGG Vorbis, or OGG Opus file.
/// @return An array of `ChapterMarker` objects sorted by start time, or `nil` if the file
///         cannot be opened or is not a supported format.
+ (nullable NSArray *)chaptersIn:(NSString *)path;

/// Replaces all chapter markers in the file with the provided chapters.
/// @param chapters Array of `ChapterMarker` objects to write.
/// @param path Absolute path to a FLAC, OGG Vorbis, or OGG Opus file.
/// @return `true` if the chapters were written successfully.
+ (bool)writeChapters:(NSArray *)chapters to:(NSString *)path;

/// Removes all Vorbis comment chapter markers from the file.
/// @param path Absolute path to a FLAC, OGG Vorbis, or OGG Opus file.
/// @return `true` if the removal succeeded.
+ (bool)removeChaptersIn:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
