// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

/// Reads, writes, and copies WAV and AIFF markers.
///
/// A RIFF WAVE file's `cue ` and `adtl` chunks are handled through TagLib, with names stored as
/// UTF-8. Everything else goes through Core Audio's `kAudioFilePropertyMarkerList`, whose WAV
/// names are Windows-1252 and so cannot hold most scripts.
@interface AudioMarkerUtil : NSObject

/// Reads all RIFF cue-point markers from the audio file.
/// @param url File URL to the audio file.
/// @return An array of `AudioMarker` objects, or an empty array if no markers are present.
+ (NSArray *)read:(NSURL *)url;

/// Replaces all markers in the audio file with the provided array.
/// @param markers Array of `AudioMarker` objects to write.
/// @param url File URL to the audio file.
/// @return `YES` if the markers were written successfully.
+ (BOOL)write:(NSArray *)markers to:(NSURL *)url;

/// Removes all RIFF cue-point markers from the audio file.
/// @param url File URL to the audio file.
/// @return `YES` if the markers were removed successfully.
+ (BOOL)remove:(NSURL *)url;

/// Copies all markers from one audio file to another.
/// @param url Source file URL to read markers from.
/// @param destination Destination file URL to write markers to.
/// @return `YES` if the copy succeeded.
+ (BOOL)copyMarkers:(NSURL *)url to:(NSURL *)destination;

@end
