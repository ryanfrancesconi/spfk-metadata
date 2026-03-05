// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#import "TagPictureRef.h"

NS_ASSUME_NONNULL_BEGIN

/// Reads and writes embedded artwork (APIC frames) in audio files via TagLib.
///
/// Initialize with a file path to extract artwork, or use `write:path:` to embed artwork.
/// Works with the `TagPictureRef` bridge type that holds a `CGImageRef`.
@interface TagPicture : NSObject

/// The extracted or to-be-written artwork, wrapping a `CGImageRef` with UTType info.
@property (nullable, nonatomic) TagPictureRef *pictureRef;

/// Reads the first APIC (embedded picture) frame from the file at the given path.
/// @param path Absolute path to the audio file.
/// @return `nil` if no artwork is found.
- (nullable instancetype)initWithPath:(nonnull NSString *)path;

/// Creates a `TagPicture` from an existing `TagPictureRef` for writing.
/// @param pictureRef The artwork reference to embed.
- (nullable instancetype)initWithPicture:(nonnull TagPictureRef *)pictureRef;

/// Embeds artwork into the audio file, replacing any existing APIC frame.
/// @param picture The artwork to write.
/// @param path Absolute path to the audio file.
/// @return `true` if the write succeeded.
+ (bool)write:(TagPictureRef *)picture
         path:(nonnull NSString *)path;

@end

NS_ASSUME_NONNULL_END
