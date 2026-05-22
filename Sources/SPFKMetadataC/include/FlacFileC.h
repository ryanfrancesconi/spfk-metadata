// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef FLACFILEC_H
#define FLACFILEC_H

#import <Foundation/Foundation.h>

#include "BEXTDescriptionC.h"
#include "TagAudioPropertiesC.h"

NS_ASSUME_NONNULL_BEGIN

/// FLAC file handler using TagLib for iXML and BEXT APPLICATION block I/O.
///
/// Reads and writes iXML and BEXT data stored in FLAC APPLICATION metadata blocks
/// (RFC 9639 § 8.4). Standard tags, artwork, and chapter markers are handled
/// separately by the generic TagLib and Xiph paths.
@interface FlacFileC : NSObject

/// Audio stream properties (sample rate, bit depth, etc.) populated after `load`.
@property(nullable, nonatomic) TagAudioPropertiesC *audioPropertiesC;

/// Broadcast Wave Extension (BEXT) data parsed from an APPLICATION block, or `nil` if absent.
@property(nullable, nonatomic) BEXTDescriptionC *bextDescriptionC;

/// Raw iXML string parsed from an APPLICATION block, or `nil` if absent.
@property(nullable, nonatomic) NSString *iXML;

/// Absolute path to the FLAC file.
@property(nonatomic, strong, nonnull) NSString *path;

/// Creates a `FlacFileC` for the FLAC file at the given path.
/// @param path Absolute path to the FLAC file.
- (instancetype)initWithPath:(nonnull NSString *)path;

/// Opens the file and reads iXML and BEXT APPLICATION blocks into memory.
/// @return `true` if the file was opened and parsed successfully.
- (bool)load;

/// Writes the current iXML and BEXT properties back to the FLAC file.
/// @return `true` if the save succeeded.
- (bool)save;

@end

NS_ASSUME_NONNULL_END

#endif /* FLACFILEC_H */
