
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stream properties as TagLib reads them, without an `AVAudioFile`.
@interface TagAudioPropertiesC : NSObject

/// Hz.
@property(nonatomic) double sampleRate;

/// Seconds, at millisecond resolution.
@property(nonatomic) double duration;

/// kbps.
@property(nonatomic) int bitRate;

@property(nonatomic) int channelCount;

/// Set only by `WaveFileC` and `FlacFileC`; 0 elsewhere.
@property(nonatomic) int bitsPerSample;

- (nonnull id)init;

@end

NS_ASSUME_NONNULL_END
