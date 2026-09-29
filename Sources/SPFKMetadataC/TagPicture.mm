// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <iostream>

#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <ImageIO/CGImageDestination.h>
#import <ImageIO/CGImageSource.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/tag.h>
#import <taglib/xiphcomment.h>

#import "StringUtil.h"
#import "TagPicture.h"
#import "TagPictureRef.h"

using namespace std;
using namespace TagLib;

// MARK: - Keys

static const auto pictureKey = String("PICTURE");
static const auto dataKey = String("data");
static const auto mimeTypeKey = String("mimeType");
static const auto descriptionKey = String("description");
static const auto pictureTypeKey = String("pictureType");

// MARK: - Static helpers

/// +1 image, or NULL. CGImageSource first; the JPEG and PNG decoders accept some marginal input it
/// rejects.
static CGImageRef createImage(NSData *data) {
    if (CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL)) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);

        if (image)
            return image;
    }

    if (CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data)) {
        CGImageRef image = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
        CFRelease(provider);

        if (image)
            return image;
    }

    if (CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data)) {
        CGImageRef image = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
        CFRelease(provider);
        return image;
    }

    return NULL;
}

static TagPictureRef *_Nullable buildPictureRef(const VariantMap &picture) {
    String pictureMimeType = picture.value(mimeTypeKey).value<String>();
    NSString *mimeType = StringUtil::utf8NSString(pictureMimeType);
    UTType *utType = [UTType typeWithMIMEType:mimeType];

    // MP4 CoverArt::Unknown gives a bare "image/", which resolves to no UTType. The bytes are
    // probed below regardless.
    if (!utType) {
        utType = [UTType typeWithIdentifier:@"public.jpeg"];
    }

    ByteVector pictureData = picture.value(dataKey).toByteVector();
    NSData *nsData = [[NSData alloc] initWithBytes:pictureData.data() length:pictureData.size()];

    CGImageRef imageRef = createImage(nsData);

    if (!imageRef)
        return nil;

    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);

    if (width == 0 || height == 0) {
        CGImageRelease(imageRef);
        return nil;
    }

    String pictureDescription = picture.value(descriptionKey).value<String>();
    String pictureType = picture.value(pictureTypeKey).value<String>();

    NSString *desc = StringUtil::utf8NSString(pictureDescription);
    NSString *pict = StringUtil::utf8NSString(pictureType);

    TagPictureRef *pictureRef = [[TagPictureRef alloc] initWithImage:imageRef
                                                              utType:utType
                                                  pictureDescription:desc
                                                         pictureType:pict];
    // TagPictureRef retains its own.
    CGImageRelease(imageRef);

    return pictureRef;
}

/// Nil when ImageIO cannot write the type.
static NSData *tryEncodeImage(CGImageRef image, NSString *typeIdentifier) {
    CFMutableDataRef buf = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef dst = CGImageDestinationCreateWithData(buf, (__bridge CFStringRef)typeIdentifier, 1, NULL);
    if (!dst) {
        CFRelease(buf);
        return nil;
    }
    CGImageDestinationAddImage(dst, image, NULL);
    bool ok = CGImageDestinationFinalize(dst);
    CFRelease(dst);
    if (!ok) {
        CFRelease(buf);
        return nil;
    }
    return (__bridge_transfer NSData *)buf;
}

/// Encodes in the picture's own type, or JPEG where ImageIO cannot write that (WebP).
static bool encodePicture(TagPictureRef *picture, VariantMap &outMap) {
    if (picture.pictureDescription) {
        const char *value = StringUtil::utf8CString(picture.pictureDescription);
        outMap.insert(descriptionKey, String(value, String::Type::UTF8));
    }

    if (picture.pictureType) {
        const char *value = StringUtil::utf8CString(picture.pictureType);
        outMap.insert(pictureTypeKey, String(value, String::Type::UTF8));
    }

    UTType *encodeType = picture.utType;
    NSData *encoded = tryEncodeImage(picture.cgImage, encodeType.identifier);

    if (!encoded) {
        encodeType = [UTType typeWithIdentifier:@"public.jpeg"];
        encoded = tryEncodeImage(picture.cgImage, encodeType.identifier);
    }

    if (!encoded)
        return false;

    NSString *mimeType = encodeType.preferredMIMEType;
    const char *mimeValue = StringUtil::utf8CString(mimeType);
    outMap.insert(mimeTypeKey, String(mimeValue, String::Type::UTF8));

    outMap.insert(dataKey, ByteVector(static_cast<const char *>(encoded.bytes), (unsigned int)encoded.length));
    return true;
}

/// FLAC artwork in the XiphComment (METADATA_BLOCK_PICTURE/COVERART), where older versions wrote it.
static List<VariantMap> flacXiphCommentPictureFallback(FileRef &fileRef) {
    if (auto *flac = dynamic_cast<FLAC::File *>(fileRef.file())) {
        if (auto *xiph = flac->xiphComment()) {
            return xiph->complexProperties(pictureKey);
        }
    }
    return {};
}

/// Leaves a FLAC with one copy of its artwork, in the native PICTURE blocks.
static void clearLegacyFlacXiphCommentPictures(FileRef &fileRef) {
    if (auto *flac = dynamic_cast<FLAC::File *>(fileRef.file())) {
        if (auto *xiph = flac->xiphComment()) {
            // These live in the picture list, which removeFields() does not reach.
            xiph->removeAllPictures();
        }
    }
}

// MARK: - TagPicture

@implementation TagPicture

- (nullable instancetype)initWithPicture:(nonnull TagPictureRef *)pictureRef {
    self = [super init];
    _pictureRef = pictureRef;
    return self;
}

// MARK: - Tag-based (uses an existing TagLib session)

+ (nullable TagPictureRef *)readFromTag:(nonnull void *)opaqueTag {
    Tag *tag = static_cast<Tag *>(opaqueTag);

    auto pictures = tag->complexProperties(pictureKey);
    if (pictures.isEmpty())
        return nil;

    return buildPictureRef(pictures.front());
}

+ (bool)write:(nullable TagPictureRef *)picture toTag:(nonnull void *)opaqueTag {
    Tag *tag = static_cast<Tag *>(opaqueTag);

    if (!picture) {
        tag->setComplexProperties(pictureKey, {});
        return true;
    }

    VariantMap map;
    if (!encodePicture(picture, map))
        return false;

    tag->setComplexProperties(pictureKey, {map});
    return true;
}

// MARK: - Path-based (opens its own FileRef)

- (nullable instancetype)initWithPath:(nonnull NSString *)path {
    FileRef fileRef(path.UTF8String);
    if (fileRef.isNull())
        return nil;

    auto pictures = fileRef.complexProperties(pictureKey);

    if (pictures.isEmpty())
        pictures = flacXiphCommentPictureFallback(fileRef);

    if (pictures.isEmpty())
        return nil;

    TagPictureRef *ref = buildPictureRef(pictures.front());
    if (!ref)
        return nil;

    self = [super init];
    _pictureRef = ref;
    return self;
}

+ (bool)write:(nullable TagPictureRef *)picture path:(nonnull NSString *)path {
    FileRef fileRef(path.UTF8String);
    if (fileRef.isNull())
        return false;

    List<VariantMap> pictures;

    if (picture) {
        VariantMap map;
        if (!encodePicture(picture, map))
            return false;

        pictures.append(map);
    }

    fileRef.setComplexProperties(pictureKey, pictures);
    clearLegacyFlacXiphCommentPictures(fileRef);
    fileRef.save();
    return true;
}

@end
