// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TAGFILE_H
#define TAGFILE_H

#import "TagAudioPropertiesC.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// File handle wrapper for TagLib providing format-agnostic tag I/O through a dictionary interface.
///
/// Opens an audio file via TagLib's `FileRef`, exposing its tag properties as an `NSDictionary`.
/// Set the `dictionary` and call `save` to write tags back. Also exposes audio properties
/// (sample rate, duration, bit rate, channels).
@interface TagFile : NSObject

/// Audio stream properties (sample rate, duration, etc.) populated after `load`.
@property(nullable, nonatomic) TagAudioPropertiesC *audioProperties;

/// Tag properties as key-value pairs. Set this before calling `save` to write changes.
@property(nullable, nonatomic) NSDictionary *dictionary;

/// Absolute path to the audio file.
@property(nonatomic, strong, nonnull) NSString *path;

/// Creates a `TagFile` for the audio file at the given path.
/// @param path Absolute path to the audio file.
- (instancetype)initWithPath:(nonnull NSString *)path;

/// Opens the file and reads tags and audio properties into memory.
/// @return `true` if the file was opened successfully.
- (bool)load;

/// Writes the current `dictionary` contents back to the file's tags.
/// @return `true` if the save succeeded.
- (bool)save;

/// Convenience: writes a dictionary of tags to a file in a single call.
/// @param dictionary Tag properties to write.
/// @param path Absolute path to the audio file.
/// @return `true` if the write succeeded.
+ (bool)write:(nonnull NSDictionary *)dictionary path:(nonnull NSString *)path;

@end

NS_ASSUME_NONNULL_END

#endif /* TAGFILE_H */
