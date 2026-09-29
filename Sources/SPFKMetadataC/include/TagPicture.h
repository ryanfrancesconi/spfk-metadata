// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#import "TagPictureRef.h"

NS_ASSUME_NONNULL_BEGIN

/// Embedded artwork through TagLib's PICTURE complex property, in any container that has one.
/// A caller already holding the file open uses `readFromTag:`/`write:toTag:`.
@interface TagPicture : NSObject

@property(nullable, nonatomic) TagPictureRef *pictureRef;

- (nullable instancetype)initWithPicture:(nonnull TagPictureRef *)pictureRef;

// MARK: - Path-based (opens its own FileRef)

/// The first picture, or for a FLAC with none the XiphComment copy older versions wrote. Nil when
/// there is none or it doesn't decode.
- (nullable instancetype)initWithPath:(nonnull NSString *)path;

/// Nil removes the artwork. False only when the file can't be opened or the image can't be encoded.
+ (bool)write:(nullable TagPictureRef *)picture path:(nonnull NSString *)path;

// MARK: - Tag-based (uses an existing TagLib session)

/// `tag` is a non-NULL `TagLib::Tag *`.
+ (nullable TagPictureRef *)readFromTag:(nonnull void *)tag;

/// `tag` is a non-NULL `TagLib::Tag *`; nil removes the artwork. Does not save.
+ (bool)write:(nullable TagPictureRef *)picture toTag:(nonnull void *)tag;

@end

NS_ASSUME_NONNULL_END
