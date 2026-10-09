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

/// Every INFO field, keyed by ID ("INAM"). On save, INFO's new contents, plus each field the file
/// holds under an ID that is a key of `id3Properties`, which takes that value.
@property(nonatomic) NSMutableDictionary *infoDictionary;

/// The ID3v2 tag's properties, keyed and joined as `TagFile.dictionary` holds them, `"RATING"`
/// included. Written through `TagFile`, so frames without a property key are kept.
@property(nonatomic) NSMutableDictionary *id3Properties;

@property(nullable, nonatomic) BEXTDescriptionC *bextDescriptionC;

@property(nullable, nonatomic) NSString *iXML;

@property(nullable, nonatomic) TagPicture *tagPicture;

/// `AudioMarker`s. Nil when the file has none.
@property(nonatomic, strong, nullable) NSArray *markers;

@property(nonatomic, strong, nonnull) NSString *path;

/// Default YES. With NO, `save` leaves ID3, INFO and the rating as they are.
@property(nonatomic) BOOL tagsNeedsSave;

/// Default NO; read only when `tagsNeedsSave` is NO. With YES, `save` writes `id3Properties`'
/// `"RATING"` and sets `infoDictionary`'s fields, an empty value removing its field.
@property(nonatomic) BOOL ratingNeedsSave;

/// Default YES. With NO, `save` leaves the `bext` chunk as it is; with YES, each field of
/// `bextDescriptionC` that differs from the stored chunk is written over it.
@property(nonatomic) BOOL bextNeedsSave;

/// Default YES. With NO, `save` leaves the iXML chunk as it is.
@property(nonatomic) BOOL iXMLNeedsSave;

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

/// `load`'s audio properties, INFO, ID3 properties, rating, BEXT and iXML: everything but the
/// markers, XMP packet and artwork.
- (bool)loadTags;

/// Rewrites every chunk whose bytes change, never moving the audio; INFO fields absent from
/// `infoDictionary` are removed. On `false`, `failedComponents` names what was not written; unless
/// it holds `WaveFileComponentsContainer`, everything else was.
- (bool)save;

/// Set by `save`.
@property(nonatomic, readonly) WaveFileComponents failedComponents;

@end

NS_ASSUME_NONNULL_END

#endif /* WAVEFILE_H */
