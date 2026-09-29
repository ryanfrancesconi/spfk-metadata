// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <ImageIO/CGImageSource.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "TagImageDecoding.h"
#import "TagPictureRef.h"

CGImageRef TagCreateImage(NSData *data) {
    CFDataRef cfData = (__bridge CFDataRef)data;
    CGImageRef image = NULL;

    CGImageSourceRef source = CGImageSourceCreateWithData(cfData, NULL);
    if (source) {
        image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);
    }

    if (!image) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(cfData);
        if (provider) {
            image = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
            CFRelease(provider);
        }
    }

    if (!image) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(cfData);
        if (provider) {
            image = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
            CFRelease(provider);
        }
    }

    return image;
}

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

    // The caller keeps its own reference.
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

    _cgImage = TagCreateImage(data);

    if (!_cgImage)
        return nil;

    return self;
}

@end
