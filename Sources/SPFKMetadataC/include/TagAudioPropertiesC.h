
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Audio stream properties read from a file via TagLib.
///
/// Populated by `TagFile` after loading a file. Provides the basic audio format information
/// (sample rate, duration, bit rate, channel count) without opening a full `AVAudioFile`.
@interface TagAudioPropertiesC : NSObject

/// Sample rate in Hz (e.g., 44100, 48000).
@property(nonatomic) double sampleRate;

/// Total duration of the audio file in seconds.
@property(nonatomic) double duration;

/// Bit rate in kilobits per second (e.g., 320 for 320 kbps MP3).
@property(nonatomic) int bitRate;

/// Number of audio channels (1 = mono, 2 = stereo, etc.).
@property(nonatomic) int channelCount;

/// Bits per sample (e.g., 16, 24, 32). Only meaningful for PCM formats like WAV/AIFF.
@property(nonatomic) int bitsPerSample;

- (nonnull id)init;

@end

NS_ASSUME_NONNULL_END
