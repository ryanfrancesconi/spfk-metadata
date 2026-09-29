// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// MP4-family chapters: a QuickTime chapter track, or a Nero `chpl` atom when there is no track.
/// Neither stores an end time, so a chapter ends where the next begins and the last at 0.
@interface MP4ChapterUtil : NSObject

/// Nil when the file can't be opened or has no chapters.
+ (nullable NSArray *)read:(NSString *)path;

/// Writes a QuickTime chapter track, replacing the existing one.
+ (bool)write:(NSArray *)chapters to:(NSString *)path;

/// Removes both the QuickTime track and the Nero atom.
+ (bool)remove:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
