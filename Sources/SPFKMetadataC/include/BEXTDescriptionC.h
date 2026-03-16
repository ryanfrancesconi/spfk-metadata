// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Broadcast Wave Extension (BEXT) chunk representation (EBU Tech 3285).
///
/// Wraps BEXT fields as Objective-C properties. Used as the bridge type
/// between the Swift `BEXTDescription` struct and the C/C++ layer.
@interface BEXTDescriptionC : NSObject

/// BWF Version 0, 1, or 2
@property (nonatomic) short version;

/// ASCII string (maximum 256 characters) containing a free description of the sequence.
/// To help applications which display only a short description, it is recommended that a
/// resume of the description is contained in the first 64 characters and the
/// last 192 characters are used for details.
@property (nonatomic) NSString *sequenceDescription;

/// UMID (Unique Material Identifier) to standard SMPTE. (Note: Added in version 1.)
@property (nonatomic) NSString *umid;

/// A <CodingHistory> field is provided in the BWF format to allow the exchange of information on previous signal processing,
/// IE: A=PCM,F=48000,W=16,M=stereo|mono,T=original
///
/// A=<ANALOGUE, PCM, MPEG1L1, MPEG1L2, MPEG1L3, MPEG2L1, MPEG2L2, MPEG2L3>
/// F=<11000,22050,24000,32000,44100,48000>
/// B=<any bit-rate allowed in MPEG 2 (ISO/IEC 13818-3)>
/// W=<8, 12, 14, 16, 18, 20, 22, 24>
/// M=<mono, stereo, dual-mono, joint-stereo>
/// T=<a free ASCII-text string for in house use. This string should contain no commas (ASCII 2Chex).
/// Examples of the contents: ID-No; codec type; A/D type>
///
/// see: https://tech.ebu.ch/docs/r/r098.pdf
@property (nonatomic) NSString *codingHistory;

/// Integrated Loudness Value of the file in LUFS. (Note: Added in version 2.)
@property (nonatomic) double loudnessIntegrated;

/// Loudness Range of the file in LU. (Note: Added in version 2.)
@property (nonatomic) double loudnessRange;

/// Maximum True Peak Value of the file in dBTP. (Note: Added in version 2.)
@property (nonatomic) float maxTruePeakLevel;

/// Highest value of the Momentary Loudness Level of the file in LUFS. (Note: Added in version 2.)
@property (nonatomic) double maxMomentaryLoudness;

/// Highest value of the Short-term Loudness Level of the file in LUFS. (Note: Added in version 2.)
@property (nonatomic) double maxShortTermLoudness;

/// The name of the originator / producer of the audio file
@property (nonatomic) NSString *originator;

/// Unambiguous reference allocated by the originating organization
@property (nonatomic) NSString *originatorReference;

/// yyyy-mm-dd
@property (nonatomic) NSString *originationDate;

/// hh:mm:ss
@property (nonatomic) NSString *originationTime;

/// Time reference in samples
/// These fields shall contain the time-code of the sequence. It is a 64-bit value which contains the first sample count since midnight.
/// First sample count since midnight, low word (UInt32)
@property (nonatomic) uint32_t timeReferenceLow;

/// Time reference in samples
/// First sample count since midnight, high word (UInt32)
@property (nonatomic) uint32_t timeReferenceHigh;

/// Combined 64bit time value of low and high words
@property (readonly) uint64_t timeReference;

/// Convenience property in seconds
@property (readonly) double timeReferenceInSeconds;

@property (nonatomic) double sampleRate;

- (instancetype)init;

/// Parses BEXT data from raw chunk bytes (from TagLib's ByteVector).
/// @param data NSData containing the raw BEXT chunk bytes.
/// @return `nil` if data is too short (< 602 bytes).
- (nullable instancetype)initWithData:(nonnull NSData *)data;

/// Serializes the BEXT properties to raw chunk bytes for writing via TagLib.
/// @return NSData containing the serialized BEXT chunk (602 + coding_history bytes).
- (nonnull NSData *)serializedData;

/// Reads the BEXT chunk from the WAV file at the given path via libsndfile.
/// @param path Absolute path to the WAV file.
/// @return `nil` if the file has no BEXT data or cannot be opened.
- (nullable instancetype)initWithPath:(nonnull NSString *)path;

/// Writes a BEXT chunk to the WAV file at the given path via libsndfile.
/// @param info The BEXT data to write.
/// @param path Absolute path to the WAV file.
/// @return `true` if the write succeeded.
+ (bool)write:(BEXTDescriptionC *)info
         path:(nonnull NSString *)path;

@end

NS_ASSUME_NONNULL_END
