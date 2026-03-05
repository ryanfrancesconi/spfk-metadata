// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

/// Core Audio–based utility for reading, writing, and copying RIFF cue-point markers in WAV files.
///
/// Uses the AudioToolbox `AudioFile` API to access the `kAudioFilePropertyMarkerList` property.
/// All methods operate on file URLs and return `AudioMarker` objects.
@interface AudioMarkerUtil : NSObject

/// Reads all RIFF cue-point markers from the audio file.
/// @param url File URL to the audio file.
/// @return An array of `AudioMarker` objects, or an empty array if no markers are present.
+ (NSArray *)getMarkers:(NSURL *)url;

/// Replaces all markers in the audio file with the provided array.
/// @param url File URL to the audio file.
/// @param markers Array of `AudioMarker` objects to write.
/// @return `YES` if the markers were written successfully.
+ (BOOL)update:(NSURL *)url
       markers:(NSArray *)markers;

/// Removes all RIFF cue-point markers from the audio file.
/// @param url File URL to the audio file.
/// @return `YES` if the markers were removed successfully.
+ (BOOL)removeAllMarkers:(NSURL *)url;

/// Copies all markers from one audio file to another.
/// @param url Source file URL to read markers from.
/// @param destination Destination file URL to write markers to.
/// @return `YES` if the copy succeeded.
+ (BOOL)copyMarkers:(NSURL *)url
            to:(NSURL *)destination;

@end
