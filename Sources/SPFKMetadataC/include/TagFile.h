// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TAGFILE_H
#define TAGFILE_H

#import "TagAudioPropertiesC.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Any TagLib format's tags as a dictionary keyed by property name.
@interface TagFile : NSObject

/// Set by `load`.
@property(nullable, nonatomic) TagAudioPropertiesC *audioProperties;

/// `"RATING"` is carried here like any key but stored in each format's own rating frame. A FLAC,
/// Vorbis or Opus file's chapter fields are left out: they are markers, read by `XiphChapterUtil`.
@property(nullable, nonatomic) NSDictionary *dictionary;

@property(nonatomic, strong, nonnull) NSString *path;

/// An MP3's XMP packet, from the ID3v2 `PRIV` frame owned by `XMP`. Set by `load`.
@property(nullable, nonatomic) NSString *xmpPacket;

/// Default NO, which keeps an MP3's stored packet. With YES, `save` replaces it with `xmpPacket`,
/// removing it when nil. Other formats ignore both.
@property(nonatomic) BOOL xmpNeedsSave;

- (instancetype)initWithPath:(nonnull NSString *)path;

/// False when the file can't be opened or has no tag.
- (bool)load;

/// Replaces every tag with `dictionary`. Artwork is kept, and so are the chapters: every ID3v2 frame
/// of an MP3 that has no property key (`CHAP`, `CTOC`, other applications' `PRIV` and `GEOB`), and
/// a Xiph comment's chapter fields, which a chapter key in `dictionary` does not replace.
- (bool)save;

/// `save`'s changes, made to an open `TagLib::FileRef *` without saving it. False only when the
/// rating cannot be written.
- (bool)writeToFileRef:(void *)fileRef;

@end

NS_ASSUME_NONNULL_END

#endif /* TAGFILE_H */
