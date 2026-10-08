// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NS_ASSUME_NONNULL_BEGIN

/// Artwork carried across the Swift/ObjC boundary. Owns a retain on `cgImage`, released on dealloc.
@interface TagPictureRef : NSObject

@property(nonatomic) CGImageRef cgImage;

@property(nonatomic, strong, nullable) NSString *pictureDescription;

/// TagLib's picture type name, e.g. "Front Cover" or "Back Cover". ID3v2 and FLAC write a name
/// TagLib does not know as type 0, "Other".
@property(nonatomic, strong, nullable) NSString *pictureType;

@property(nonatomic, strong, nonnull) UTType *utType;

/// The picture's bytes as a file stores them, with their MIME type; written as they are instead of
/// re-encoding `cgImage`. Nil for an image that has not come from a file unchanged.
@property(nonatomic, strong, nullable) NSData *storedData;
@property(nonatomic, strong, nullable) NSString *storedMimeType;

/// Retains `cgImage`.
- (nonnull id)initWithImage:(CGImageRef)cgImage
                     utType:(UTType *)utType
         pictureDescription:(NSString *)pictureDescription
                pictureType:(NSString *)pictureType;

/// Any format `CGImageSource` reads. Nil when it can't.
- (nullable instancetype)initWithURL:(NSURL *)url
                  pictureDescription:(NSString *)pictureDescription
                         pictureType:(NSString *)pictureType;

@end

NS_ASSUME_NONNULL_END
