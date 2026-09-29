// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NS_ASSUME_NONNULL_BEGIN

/// Artwork carried across the Swift/ObjC boundary. Owns a retain on `cgImage`, released on dealloc.
@interface TagPictureRef : NSObject

@property(nonatomic) CGImageRef cgImage;

/// e.g. "Front Cover".
@property(nonatomic, strong, nullable) NSString *pictureDescription;

/// The ID3 APIC type name, e.g. "Cover (front)".
@property(nonatomic, strong, nullable) NSString *pictureType;

@property(nonatomic, strong, nonnull) UTType *utType;

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
