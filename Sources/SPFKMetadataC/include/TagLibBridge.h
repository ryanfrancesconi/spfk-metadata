// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#import "TagPictureRef.h"

NS_ASSUME_NONNULL_BEGIN

/// Static utility class providing core TagLib operations for reading, writing,
/// copying, and stripping audio metadata tags across all TagLib-supported formats.
@interface TagLibBridge : NSObject

/// Reads all tags from the file as a dictionary keyed by TagLib property names.
/// @param path Absolute path to the audio file.
/// @return A mutable dictionary of tag properties, or `nil` if the file cannot be opened.
+ (nullable NSMutableDictionary *)getProperties:(NSString *)path;

/// Writes a dictionary of tag properties to the file, replacing existing tags.
/// @param path Absolute path to the audio file.
/// @param dictionary Tag properties keyed by TagLib property names.
/// @return `true` if the write succeeded.
+ (bool)setProperties:(NSString *)path dictionary:(NSDictionary *)dictionary;

/// Reads the title tag from the file.
/// @param path Absolute path to the audio file.
/// @return The title string, or `nil` if not present.
+ (nullable NSString *)getTitle:(NSString *)path;

/// Writes or updates the title tag in the file.
/// @param path Absolute path to the audio file.
/// @param comment The new title string.
/// @return `true` if the write succeeded.
+ (bool)setTitle:(NSString *)path title:(NSString *)comment;

/// Reads the comment tag from the file.
/// @param path Absolute path to the audio file.
/// @return The comment string, or `nil` if not present.
+ (nullable NSString *)getComment:(NSString *)path;

/// Writes or updates the comment tag in the file.
/// @param path Absolute path to the audio file.
/// @param comment The new comment string.
/// @return `true` if the write succeeded.
+ (bool)setComment:(NSString *)path comment:(NSString *)comment;

/// Strips all tags (ID3, APE, Xiph, etc.) from the file.
/// @param path Absolute path to the audio file.
/// @return `true` if the operation succeeded.
+ (bool)removeAllTags:(NSString *)path;

/// Copies all tags from one file to another, overwriting existing tags in the destination.
/// @param path Source file path to read tags from.
/// @param toPath Destination file path to write tags to.
/// @return `true` if the copy succeeded.
+ (bool)copyTagsFromPath:(NSString *)path toPath:(NSString *)toPath;

@end

NS_ASSUME_NONNULL_END
