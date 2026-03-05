// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <AudioToolbox/AudioFile.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper around Core Audio's `AudioFileMarker` C struct for Swift interop.
///
/// Represents a single RIFF cue-point marker with a name, time position, and optional SMPTE timecode.
/// Used by `AudioMarkerUtil` for reading and writing markers in WAV files via the AudioToolbox API.
@interface AudioMarker : NSObject

/// Display name of the marker, or `nil` if unnamed.
@property (nonatomic, nullable) NSString *name;

/// Marker position in seconds from the start of the file.
@property (nonatomic) NSTimeInterval time;

/// Sample rate of the audio file (used to convert between time and sample position).
@property (nonatomic) Float64 sampleRate;

/// Unique marker identifier within the file (corresponds to the RIFF cue-point ID).
@property (nonatomic) SInt32 markerID;

/// Core Audio marker type flag (e.g., `kAudioFileMarkerType_Generic`).
@property (nonatomic) UInt32 type;

/// SMPTE timecode associated with the marker, if available.
@property (nonatomic) AudioFile_SMPTE_Time timecode;

/// Creates an `AudioMarker` with a name, time position, sample rate, and ID.
/// @param name Display name of the marker.
/// @param time Position in seconds from the start of the file.
/// @param sampleRate Sample rate of the audio file.
/// @param markerID Unique marker identifier.
- (nonnull id)initWithName:(nonnull NSString *)name
                      time:(NSTimeInterval)time
                sampleRate:(Float64)sampleRate
                  markerID:(SInt32)markerID;

/// Returns the marker position as a sample frame offset (``time * sampleRate``).
- (Float64)framePosition;

@end

NS_ASSUME_NONNULL_END
