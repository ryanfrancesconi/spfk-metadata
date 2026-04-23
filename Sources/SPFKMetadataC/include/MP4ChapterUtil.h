// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TagLib-based utility for reading, writing, and removing Nero-style chapter markers (chpl atom)
/// in MP4/M4A files.
///
/// Operates via TagLib's `MP4::File` integrated chapter API, which handles both Nero-style
/// `chpl` atoms and QuickTime chapter tracks.
/// Chapter data is represented as `ChapterMarker` objects with start time, end time, and name.
@interface MP4ChapterUtil : NSObject

/// Reads all Nero-style chapter markers from the MP4 file at the given path.
/// @param path Absolute path to an MP4/M4A file.
/// @return An array of `ChapterMarker` objects sorted by start time, or `nil` if the file
///         cannot be opened or has no chapter markers.
+ (nullable NSArray *)chaptersIn:(NSString *)path;

/// Replaces all chapter markers in the MP4 file with the provided chapters.
/// @param chapters Array of `ChapterMarker` objects to write.
/// @param path Absolute path to an MP4/M4A file.
/// @return `true` if the chapters were written successfully.
+ (bool)writeChapters:(NSArray *)chapters to:(NSString *)path;

/// Removes all Nero-style chapter markers from the MP4 file.
/// @param path Absolute path to an MP4/M4A file.
/// @return `true` if the removal succeeded.
+ (bool)removeChaptersIn:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
