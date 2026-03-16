// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#import "TagPictureRef.h"

NS_ASSUME_NONNULL_BEGIN

/// Reads and writes embedded artwork (APIC frames) in audio files via TagLib.
///
/// Initialize with a file path to extract artwork, or use `write:path:` to embed artwork.
/// Works with the `TagPictureRef` bridge type that holds a `CGImageRef`.
///
/// For callers that already have an open TagLib session (e.g., `WaveFileC`), use the
/// tag-based class methods `readFromTag:` / `write:toTag:` to avoid a redundant file open.
@interface TagPicture : NSObject

/// The extracted or to-be-written artwork, wrapping a `CGImageRef` with UTType info.
@property(nullable, nonatomic) TagPictureRef *pictureRef;

/// Creates a `TagPicture` from an existing `TagPictureRef` for writing.
/// @param pictureRef The artwork reference to embed.
- (nullable instancetype)initWithPicture:(nonnull TagPictureRef *)pictureRef;

// MARK: - Path-based (opens its own FileRef)

/// Reads the first APIC (embedded picture) frame from the file at the given path.
/// @param path Absolute path to the audio file.
/// @return `nil` if no artwork is found.
- (nullable instancetype)initWithPath:(nonnull NSString *)path;

/// Embeds artwork into the audio file, replacing any existing APIC frame.
/// @param picture The artwork to write.
/// @param path Absolute path to the audio file.
/// @return `true` if the write succeeded.
+ (bool)write:(TagPictureRef *)picture path:(nonnull NSString *)path;

// MARK: - Tag-based (uses an existing TagLib session)

/// Reads the first APIC frame from an already-open TagLib Tag.
/// @param tag Opaque pointer to a `TagLib::Tag *`. Must not be NULL.
/// @return `nil` if no artwork is found.
+ (nullable TagPictureRef *)readFromTag:(nonnull void *)tag;

/// Writes or clears artwork on an already-open TagLib Tag.
/// Pass `nil` for `picture` to remove existing artwork.
/// @param picture The artwork to embed, or `nil` to clear.
/// @param tag Opaque pointer to a `TagLib::Tag *`. Must not be NULL.
/// @return `true` if the write succeeded.
+ (bool)write:(nullable TagPictureRef *)picture toTag:(nonnull void *)tag;

@end

NS_ASSUME_NONNULL_END
