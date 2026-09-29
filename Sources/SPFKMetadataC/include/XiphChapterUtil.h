// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Chapters in a FLAC, Vorbis or Opus XiphComment: `CHAPTER000=HH:MM:SS.mmm`, `CHAPTER000NAME`, and
/// for a region `CHAPTER000END`. Without an END, a chapter ends where the next begins.
@interface XiphChapterUtil : NSObject

/// In chapter-number order. Nil when the file can't be opened, isn't Xiph, or has no chapters.
+ (nullable NSArray *)read:(NSString *)path;

/// Replaces every CHAPTER* field.
+ (bool)write:(NSArray *)chapters to:(NSString *)path;

+ (bool)remove:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
