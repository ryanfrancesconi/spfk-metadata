// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Represents a single chapter region within an audio file, defined by a time range and optional name.
///
/// Used by `MPEGChapterUtil` for ID3v2 CHAP frame I/O and by the Swift `AudioMarkerDescription`
/// type for format-agnostic chapter handling.
@interface ChapterMarker : NSObject

/// Display name of the chapter, or `nil` if unnamed.
@property (nonatomic, strong, nullable) NSString *name;

/// Start time of the chapter in seconds from the beginning of the file.
@property (nonatomic) NSTimeInterval startTime;

/// End time of the chapter in seconds from the beginning of the file.
@property (nonatomic) NSTimeInterval endTime;

/// Creates a `ChapterMarker` with a name, start time, and end time.
/// @param name Display name of the chapter.
/// @param startTime Start time in seconds.
/// @param endTime End time in seconds.
- (nonnull id)initWithName:(nonnull NSString *)name
                 startTime:(NSTimeInterval)startTime
                   endTime:(NSTimeInterval)endTime;

@end

NS_ASSUME_NONNULL_END
