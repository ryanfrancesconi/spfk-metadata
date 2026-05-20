// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <ImageIO/CGImageSource.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "TagPictureRef.h"

@implementation TagPictureRef

- (void)dealloc {
    if (_cgImage) {
        CGImageRelease(_cgImage);
        _cgImage = NULL;
    }
}

- (nonnull id)initWithImage:(CGImageRef)cgImage
                     utType:(UTType *)utType
         pictureDescription:(NSString *)pictureDescription
                pictureType:(NSString *)pictureType {
    self = [super init];

    // Retain because caller retains its own reference.
    // CGImageCreate returns +1 but when called from Swift,
    // the caller's CGImage is still alive and owns its reference.
    _cgImage = CGImageRetain(cgImage);
    _pictureDescription = pictureDescription;
    _utType = utType;
    _pictureType = pictureType;

    if (_pictureType == nil) {
        _pictureType = @"Front Cover";
    }

    return self;
}

- (nullable instancetype)initWithURL:(NSURL *)url
                  pictureDescription:(NSString *)pictureDescription
                         pictureType:(NSString *)pictureType {
    self = [super init];

    _pictureDescription = pictureDescription;
    _utType = [UTType typeWithFilenameExtension:url.pathExtension];
    _pictureType = pictureType;

    if (_pictureType == nil) {
        _pictureType = @"Front Cover";
    }

    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data)
        return nil;

    // Generic path: handles JPEG, PNG, WebP, HEIC, TIFF, GIF, etc.
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (source) {
        _cgImage = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);
    }

    // JPEG fallback for marginal-but-decodable input that CGImageSource may reject.
    if (!_cgImage) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        if (provider) {
            _cgImage = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
            CFRelease(provider);
        }
    }

    // PNG fallback for the same reason.
    if (!_cgImage) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        if (provider) {
            _cgImage = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
            CFRelease(provider);
        }
    }

    if (!_cgImage)
        return nil;

    return self;
}

@end
