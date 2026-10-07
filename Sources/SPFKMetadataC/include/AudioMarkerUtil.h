// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads, writes, and copies WAV and AIFF markers.
///
/// A RIFF WAVE file's `cue ` and `adtl` chunks are handled through TagLib, with names stored as
/// UTF-8. Everything else goes through Core Audio's `kAudioFilePropertyMarkerList`, whose WAV
/// names are Windows-1252 and so cannot hold most scripts.
@interface AudioMarkerUtil : NSObject

/// Nil when there are none or the file can't be opened.
+ (nullable NSArray *)read:(NSURL *)url;

/// Replaces every marker. Positions use the file's sample rate, not each marker's.
+ (BOOL)write:(NSArray *)markers to:(NSURL *)url;

+ (BOOL)remove:(NSURL *)url;

/// NO when the source has no markers.
+ (BOOL)copyMarkers:(NSURL *)url to:(NSURL *)destination;

@end

NS_ASSUME_NONNULL_END
