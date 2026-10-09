// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads, writes, and copies WAV and AIFF markers.
///
/// A RIFF, RF64 or BW64 WAVE's `cue ` and `adtl` chunks are handled through TagLib, with names
/// stored as UTF-8. AIFF and Wave64 go through Core Audio's `kAudioFilePropertyMarkerList`.
@interface AudioMarkerUtil : NSObject

/// Empty when there are none; nil when the file or its marker list can't be read.
+ (nullable NSArray *)read:(NSURL *)url;

/// Replaces every marker. Positions use the file's sample rate, not each marker's.
+ (BOOL)write:(NSArray *)markers to:(NSURL *)url;

+ (BOOL)remove:(NSURL *)url;

/// NO when the source has no markers.
+ (BOOL)copyMarkers:(NSURL *)url to:(NSURL *)destination;

@end

NS_ASSUME_NONNULL_END
