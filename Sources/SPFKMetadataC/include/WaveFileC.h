// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef WAVEFILE_H
#define WAVEFILE_H

#import <Foundation/Foundation.h>

#include "BEXTDescriptionC.h"
#include "TagAudioPropertiesC.h"
#include "TagPicture.h"

NS_ASSUME_NONNULL_BEGIN

/// A RIFF, RF64 or BW64 WAVE's INFO, ID3, BEXT, iXML, artwork and markers through TagLib.
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

/// `AudioMarker`s. Nil when the file has none.
@property(nonatomic, strong, nullable) NSArray *markers;

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

/// Rewrites every chunk whose bytes change, never moving the audio; INFO fields absent from
/// `infoDictionary` are removed.
- (bool)save;

@end

NS_ASSUME_NONNULL_END

#endif /* WAVEFILE_H */
