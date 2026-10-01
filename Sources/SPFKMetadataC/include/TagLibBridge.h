// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#import "TagPictureRef.h"

NS_ASSUME_NONNULL_BEGIN

/// Path-based TagLib operations; each call opens the file itself.
@interface TagLibBridge : NSObject

/// Keyed by TagLib property name, with `"RATING"` added. Nil when the file can't be opened.
+ (nullable NSMutableDictionary *)getProperties:(NSString *)path;

/// Replaces every tag with the dictionary; artwork is kept.
+ (bool)setProperties:(NSString *)path dictionary:(NSDictionary *)dictionary;

+ (nullable NSString *)getTitle:(NSString *)path;

+ (bool)setTitle:(NSString *)path title:(NSString *)comment;

+ (nullable NSString *)getComment:(NSString *)path;

+ (bool)setComment:(NSString *)path comment:(NSString *)comment;

/// Vorbis, Opus and AIFF keep anything outside their mapped properties.
+ (bool)removeAllTags:(NSString *)path;

/// Replaces the destination's tags with the source's, rating included. True, touching nothing, when
/// the source has no tags.
+ (bool)copyTagsFromPath:(NSString *)path toPath:(NSString *)toPath;

/// The XMP packet a WAV's `_PMX` chunk or an MP3's ID3v2 `PRIV` frame holds, as stored: no native
/// metadata is merged in. Nil when there is none, or for any other format.
+ (nullable NSString *)storedXMPPacket:(NSString *)path;

/// Replaces that packet, removing it when `packet` is nil, and writes nothing else. False for any
/// other format.
+ (bool)setStoredXMPPacket:(nullable NSString *)packet path:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
