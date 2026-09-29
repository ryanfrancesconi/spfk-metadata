// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A chapter as the MP3, MP4 and Xiph chapter utilities read and write it. Times in seconds.
@interface ChapterMarker : NSObject

@property(nonatomic, strong, nullable) NSString *name;

@property(nonatomic) NSTimeInterval startTime;

/// 0 when the format stores none and nothing follows.
@property(nonatomic) NSTimeInterval endTime;

- (nonnull id)initWithName:(nonnull NSString *)name startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime;

@end

NS_ASSUME_NONNULL_END
