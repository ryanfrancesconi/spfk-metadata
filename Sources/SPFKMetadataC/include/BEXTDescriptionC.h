// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The BWF `bext` chunk (EBU Tech 3285), bridging `BEXTDescription` to the C++ layer.
@interface BEXTDescriptionC : NSObject

/// 0, 1 or 2. UMID needs 1, loudness 2.
@property(nonatomic) short version;

/// Up to 256 ASCII characters; the spec suggests a summary in the first 64.
@property(nonatomic) NSString *sequenceDescription;

/// SMPTE UMID, hex-encoded; 64 bytes on disk.
@property(nonatomic) NSString *umid;

/// e.g. `A=PCM,F=48000,W=16,M=stereo,T=original`, per EBU R 98 (https://tech.ebu.ch/docs/r/r098.pdf).
@property(nonatomic) NSString *codingHistory;

/// LUFS.
@property(nonatomic) double loudnessIntegrated;

/// LU.
@property(nonatomic) double loudnessRange;

/// dBTP.
@property(nonatomic) float maxTruePeakLevel;

/// LUFS.
@property(nonatomic) double maxMomentaryLoudness;

/// LUFS.
@property(nonatomic) double maxShortTermLoudness;

@property(nonatomic) NSString *originator;

@property(nonatomic) NSString *originatorReference;

/// yyyy-mm-dd
@property(nonatomic) NSString *originationDate;

/// hh:mm:ss
@property(nonatomic) NSString *originationTime;

/// The first sample's count since midnight, as two 32-bit words.
@property(nonatomic) uint32_t timeReferenceLow;
@property(nonatomic) uint32_t timeReferenceHigh;
@property(readonly) uint64_t timeReference;

/// 0 until `sampleRate` is set.
@property(readonly) double timeReferenceInSeconds;

/// Not part of the chunk; the reader copies it from the file.
@property(nonatomic) double sampleRate;

- (instancetype)init;

/// Nil for fewer than 602 bytes, the fixed part of the chunk.
- (nullable instancetype)initWithData:(nonnull NSData *)data;

/// 602 bytes plus the coding history. Non-ASCII text is written as zeros.
- (nonnull NSData *)serializedData;

@end

NS_ASSUME_NONNULL_END
