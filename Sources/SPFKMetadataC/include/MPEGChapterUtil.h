// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TagLib-based utility for reading, writing, and removing ID3v2 chapter frames (CHAP) in MP3 files.
///
/// Operates on MPEG files via TagLib's `MPEG::File` API. Chapter data is represented as
/// `ChapterMarker` objects with start time, end time, and an optional name.
@interface MPEGChapterUtil : NSObject

/// Reads all ID3v2 CHAP frames from the MP3 file at the given path.
/// @param path Absolute path to the MP3 file.
/// @return An array of `ChapterMarker` objects sorted by start time, or `nil` if the file cannot be opened.
+ (nullable NSArray *)getChapters:(NSString *)path;

/// Replaces all CHAP frames in the MP3 file with the provided chapter markers.
/// @param path Absolute path to the MP3 file.
/// @param chapters Array of `ChapterMarker` objects to write.
/// @return `true` if the chapters were written successfully.
+ (bool)update:(NSString *)path
      chapters:(NSArray *)chapters;

/// Removes all ID3v2 CHAP frames from the MP3 file.
/// @param path Absolute path to the MP3 file.
/// @return `true` if the removal succeeded.
+ (bool)removeAllChapters:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
