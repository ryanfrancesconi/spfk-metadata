// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// MP3 chapters as ID3v2 CHAP frames, named by an embedded TIT2 or else the element ID.
@interface MPEGChapterUtil : NSObject

/// In frame order. Nil when the file can't be opened, isn't MPEG, or has no ID3v2 tag.
+ (nullable NSArray *)read:(NSString *)path;

/// Replaces every CHAP frame.
+ (bool)write:(NSArray *)chapters to:(NSString *)path;

+ (bool)remove:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
