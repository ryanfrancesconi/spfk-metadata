// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridge container holding a `CGImageRef` with its UTType, description, and type metadata.
///
/// Manages Core Graphics reference counting across the Swift/ObjC boundary — the `CGImageRef`
/// is retained on creation and released on dealloc. Used by `TagPicture` for TagLib artwork I/O
/// and by `ImageDescription` for Swift-side artwork handling.
@interface TagPictureRef : NSObject

/// The artwork image. Retained by this object; released on dealloc.
@property(nonatomic) CGImageRef cgImage;

/// Optional text description of the picture (e.g., "Front Cover").
@property(nonatomic, strong, nullable) NSString *pictureDescription;

/// Picture type string (e.g., "Cover (front)") per the ID3 APIC specification.
@property(nonatomic, strong, nullable) NSString *pictureType;

/// The image's Uniform Type Identifier (e.g., `UTTypeJPEG`, `UTTypePNG`).
@property(nonatomic, strong, nonnull) UTType *utType;

/// Creates a `TagPictureRef` from a `CGImageRef`. The image is retained.
/// @param cgImage The image to wrap.
/// @param utType The image's UTType.
/// @param pictureDescription Optional description text.
/// @param pictureType Optional type string per the APIC spec.
- (nonnull id)initWithImage:(CGImageRef)cgImage
                     utType:(UTType *)utType
         pictureDescription:(NSString *)pictureDescription
                pictureType:(NSString *)pictureType;

/// Creates a `TagPictureRef` by loading an image from a file URL.
/// Supports JPEG, PNG, WebP, HEIC, TIFF, GIF, and any other format
/// supported by `CGImageSource` on the current platform.
/// @param url URL to an image file.
/// @param pictureDescription Optional description text.
/// @param pictureType Optional type string per the APIC spec.
/// @return `nil` if the image cannot be loaded.
- (nullable instancetype)initWithURL:(NSURL *)url
                  pictureDescription:(NSString *)pictureDescription
                         pictureType:(NSString *)pictureType;

@end

NS_ASSUME_NONNULL_END
