// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef WAVEFILE_H
#define WAVEFILE_H

#import <Foundation/Foundation.h>

#include "BEXTDescriptionC.h"
#include "TagAudioPropertiesC.h"
#include "TagPicture.h"

NS_ASSUME_NONNULL_BEGIN

/// RIFF WAV file handler using libsndfile and TagLib for comprehensive WAV metadata I/O.
///
/// Reads and writes INFO chunks, ID3 tags, BEXT broadcast extension data, iXML,
/// cue point markers, and embedded artwork. Because libsndfile rewrites the file on save,
/// all chunks must be populated before calling `save`.
@interface WaveFileC : NSObject

/// Audio stream properties (sample rate, duration, etc.) populated after `load`.
@property (nullable, nonatomic) TagAudioPropertiesC *audioPropertiesC;

/// RIFF INFO chunk tags as key-value pairs (e.g., "INAM" = "Song Title").
@property (nonatomic) NSMutableDictionary *infoDictionary;

/// ID3v2 tags embedded in the WAV file as key-value pairs (e.g., "TIT2" = "Song Title").
@property (nonatomic) NSMutableDictionary *id3Dictionary;

/// Broadcast Wave Extension (BEXT) chunk data, or `nil` if not present.
@property (nullable, nonatomic) BEXTDescriptionC *bextDescriptionC;

/// Raw iXML chunk string, or `nil` if not present.
@property (nullable, nonatomic) NSString *iXML;

/// Embedded artwork extracted via TagLib, or `nil` if not present.
@property (nullable, nonatomic) TagPicture *tagPicture;

/// Array of `AudioMarker` objects representing RIFF cue points.
@property (nonatomic, strong, nonnull) NSArray *markers;

/// Absolute path to the WAV file.
@property (nonatomic, strong, nonnull) NSString *path;

- (instancetype)init;

/// Creates a `WaveFileC` for the WAV file at the given path.
/// @param path Absolute path to the WAV file.
- (instancetype)initWithPath:(nonnull NSString *)path;

/// Opens the file and reads all chunks (INFO, ID3, BEXT, iXML, markers, artwork) into memory.
/// @return `true` if the file was opened and parsed successfully.
- (bool)load;

/// Writes all current properties back to the WAV file. All chunks are rewritten together.
/// @return `true` if the save succeeded.
- (bool)save;

@end

NS_ASSUME_NONNULL_END

#endif /* WAVEFILE_H */
