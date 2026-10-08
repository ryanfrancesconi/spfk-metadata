// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef FLACFILEC_H
#define FLACFILEC_H

#import <Foundation/Foundation.h>

#include "BEXTDescriptionC.h"
#include "TagAudioPropertiesC.h"

NS_ASSUME_NONNULL_BEGIN

/// A FLAC's iXML and BEXT, stored in APPLICATION blocks (RFC 9639 § 8.4). Tags, artwork and chapters
/// go through the generic paths.
@interface FlacFileC : NSObject

/// Set by `load`.
@property(nullable, nonatomic) TagAudioPropertiesC *audioPropertiesC;

@property(nullable, nonatomic) BEXTDescriptionC *bextDescriptionC;

@property(nullable, nonatomic) NSString *iXML;

/// False leaves the file's BEXT block as it is, whatever `bextDescriptionC` holds. Defaults to true.
@property(nonatomic) bool bextNeedsSave;

@property(nonatomic, strong, nonnull) NSString *path;

- (instancetype)initWithPath:(nonnull NSString *)path;

/// False when the file can't be opened or isn't FLAC.
- (bool)load;

/// A nil property removes its block.
- (bool)save;

/// `save`'s change, made to an open `TagLib::File *` without saving it. False when it is not a FLAC
/// file.
- (bool)writeToFile:(void *)file;

@end

NS_ASSUME_NONNULL_END

#endif /* FLACFILEC_H */
