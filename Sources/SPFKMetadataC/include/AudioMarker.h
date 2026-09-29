// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <AudioToolbox/AudioFile.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A WAV or AIFF marker, shaped after Core Audio's `AudioFileMarker`.
@interface AudioMarker : NSObject

@property(nonatomic, nullable) NSString *name;

/// Seconds.
@property(nonatomic) NSTimeInterval time;

/// Ignored on write; positions use the file's own rate.
@property(nonatomic) Float64 sampleRate;

/// The WAV cue-point ID.
@property(nonatomic) SInt32 markerID;

/// e.g. `kAudioFileMarkerType_Generic`.
@property(nonatomic) UInt32 type;

@property(nonatomic) AudioFile_SMPTE_Time timecode;

- (nonnull id)initWithName:(nonnull NSString *)name
                      time:(NSTimeInterval)time
                sampleRate:(Float64)sampleRate
                  markerID:(SInt32)markerID;

/// `time * sampleRate`.
- (Float64)framePosition;

@end

NS_ASSUME_NONNULL_END
