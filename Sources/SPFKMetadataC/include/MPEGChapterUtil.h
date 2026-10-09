// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// MP3 chapters as ID3v2 CHAP frames, named by an embedded TIT2 or else the element ID.
@interface MPEGChapterUtil : NSObject

/// In frame order; empty when it isn't MPEG or has no ID3v2 tag. Nil when the file can't be opened.
+ (nullable NSArray *)read:(NSString *)path;

/// Replaces every CHAP frame.
+ (bool)write:(NSArray *)chapters to:(NSString *)path;

/// `write:to:`'s change, made to an open `TagLib::File *` without saving it.
+ (bool)write:(NSArray *)chapters toFile:(void *)file;

+ (bool)remove:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
