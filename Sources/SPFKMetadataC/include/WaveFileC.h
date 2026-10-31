// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef WAVEFILE_H
#define WAVEFILE_H

#import <Foundation/Foundation.h>

#include "BEXTDescriptionC.h"
#include "TagAudioPropertiesC.h"
#include "TagPicture.h"

NS_ASSUME_NONNULL_BEGIN

/// What a failed `-[WaveFileC save]` could not write.
typedef NS_OPTIONS(NSUInteger, WaveFileComponents) {
    WaveFileComponentsNone = 0,
    /// The file could not be opened or written: nothing was saved.
    WaveFileComponentsContainer = 1 << 0,
    WaveFileComponentsRating = 1 << 1,
    WaveFileComponentsMarkers = 1 << 2,
    WaveFileComponentsArtwork = 1 << 3,
};

/// A RIFF, RF64 or BW64 WAVE's INFO, ID3, BEXT, iXML, artwork and markers through TagLib.
@interface WaveFileC : NSObject

/// Set by `load`.
@property(nullable, nonatomic) TagAudioPropertiesC *audioPropertiesC;

/// Set by `load` and `loadTags`: the frames in `data`, or -1 where only Core Audio can say how
/// many it plays (a compressed or malformed file).
@property(nonatomic, readonly) int64_t frameCount;

/// Every INFO field, keyed by ID ("INAM"). On save, the fields set, an empty value removing its
/// field; every field it does not name is left as it is.
@property(nonatomic) NSMutableDictionary *infoDictionary;

/// The ID3v2 tag's properties, keyed and joined as `TagFile.dictionary` holds them, `"RATING"`
/// included. Written through `TagFile`, so frames without a property key are kept.
@property(nonatomic) NSMutableDictionary *id3Properties;

@property(nullable, nonatomic) BEXTDescriptionC *bextDescriptionC;

@property(nullable, nonatomic) NSString *iXML;

/// Set by `load` and `loadTags`: each DISP chunk's payload in file order, its 32-bit clipboard
/// format ID first. Never written; `save` leaves DISP as it is.
@property(nonatomic, readonly) NSArray<NSData *> *dispPayloads;

@property(nullable, nonatomic) TagPicture *tagPicture;

/// `AudioMarker`s. Nil when the file has none.
@property(nonatomic, strong, nullable) NSArray *markers;

@property(nonatomic, strong, nonnull) NSString *path;

/// Default true. With false, `save` leaves ID3, INFO and the rating as they are.
@property(nonatomic) bool tagsNeedsSave;

/// Default false; read only when `tagsNeedsSave` is false. With true, `save` writes `id3Properties`'
/// `"RATING"` and sets `infoDictionary`'s fields, an empty value removing its field.
@property(nonatomic) bool ratingNeedsSave;

/// Default true. With false, `save` leaves the `bext` chunk as it is; with true, each field of
/// `bextDescriptionC` that differs from the stored chunk is written over it.
@property(nonatomic) bool bextNeedsSave;

/// Default true. With false, `save` leaves the iXML chunk as it is.
@property(nonatomic) bool iXMLNeedsSave;

/// Default true.
@property(nonatomic) bool markersNeedsSave;

/// Default true. With true, a nil `tagPicture` removes the artwork.
@property(nonatomic) bool artworkNeedsSave;

/// The `_PMX` chunk's XMP packet. Set by `load`.
@property(nullable, nonatomic) NSString *xmpPacket;

/// Default false, which keeps the stored packet. With true, `save` replaces it with `xmpPacket`,
/// removing the chunk when nil.
@property(nonatomic) bool xmpNeedsSave;

- (instancetype)init;

- (instancetype)initWithPath:(nonnull NSString *)path;

- (bool)load;

/// `load`'s audio properties, INFO, ID3 properties, rating, BEXT and iXML: everything but the
/// markers, XMP packet and artwork.
- (bool)loadTags;

/// Rewrites every chunk whose bytes change, never moving the audio. On `false`, `failedComponents` names what was not written; unless
/// it holds `WaveFileComponentsContainer`, everything else was.
- (bool)save;

/// Set by `save`.
@property(nonatomic, readonly) WaveFileComponents failedComponents;

@end

NS_ASSUME_NONNULL_END

#endif /* WAVEFILE_H */
