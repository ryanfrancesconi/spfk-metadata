// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef WAVEFILE_H
#define WAVEFILE_H

#import <Foundation/Foundation.h>

#include "BEXTDescriptionC.h"
#include "TagAudioPropertiesC.h"
#include "TagPicture.h"

NS_ASSUME_NONNULL_BEGIN

/// A WAV's INFO, ID3, BEXT, iXML, artwork and markers through TagLib. Markers in RF64 and BW64 go
/// through Core Audio instead.
@interface WaveFileC : NSObject

/// Set by `load`.
@property(nullable, nonatomic) TagAudioPropertiesC *audioPropertiesC;

/// Keyed by INFO field ID ("INAM").
@property(nonatomic) NSMutableDictionary *infoDictionary;

/// Keyed by frame ID ("TIT2"), a TXXX by its description, plus `"RATING"`. Text frames only;
/// `save` leaves binary frames (`PRIV`, `UFID`, `GEOB`, `CHAP`, …) in the file as they are.
@property(nonatomic) NSMutableDictionary *id3Dictionary;

@property(nullable, nonatomic) BEXTDescriptionC *bextDescriptionC;

@property(nullable, nonatomic) NSString *iXML;

@property(nullable, nonatomic) TagPicture *tagPicture;

/// `AudioMarker`s.
@property(nonatomic, strong, nonnull) NSArray *markers;

@property(nonatomic, strong, nonnull) NSString *path;

/// Default YES.
@property(nonatomic) BOOL markersNeedsSave;

/// Default YES. With YES, a nil `tagPicture` removes the artwork.
@property(nonatomic) BOOL imageNeedsSave;

/// The `_PMX` chunk's XMP packet. Set by `load`.
@property(nullable, nonatomic) NSString *xmpPacket;

/// Default NO, which keeps the stored packet. With YES, `save` replaces it with `xmpPacket`,
/// removing the chunk when nil.
@property(nonatomic) BOOL xmpNeedsSave;

- (instancetype)init;

- (instancetype)initWithPath:(nonnull NSString *)path;

- (bool)load;

/// Rewrites every chunk; INFO fields absent from `infoDictionary` are removed.
- (bool)save;

@end

NS_ASSUME_NONNULL_END

#endif /* WAVEFILE_H */
