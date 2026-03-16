// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
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

    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)[NSData dataWithContentsOfURL:url]);

    if (_utType == UTTypeJPEG) {
        _cgImage = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    } else if (_utType == UTTypePNG) {
        _cgImage = CGImageCreateWithPNGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    } else {
        NSLog(@"Image must be either JPEG or PNG");
        CFRelease(dataProvider);
        return nil;
    }

    CFRelease(dataProvider);

    return self;
}

@end
