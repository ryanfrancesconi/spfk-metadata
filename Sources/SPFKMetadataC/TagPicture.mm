// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <iostream>
#import <vector>

#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <ImageIO/CGImageDestination.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import <taglib/fileref.h>
#import <taglib/tag.h>

#import "StringUtil.h"
#import "TagPicture.h"
#import "TagPictureRef.h"

using namespace std;
using namespace TagLib;

// MARK: - TagLib string constants

static const auto pictureKey = String("PICTURE");
static const auto dataKey = String("data");
static const auto mimeTypeKey = String("mimeType");
static const auto descriptionKey = String("description");
static const auto pictureTypeKey = String("pictureType");

@implementation TagPicture

- (nullable instancetype)initWithPicture:(nonnull TagPictureRef *)pictureRef {
    self = [super init];
    _pictureRef = pictureRef;
    return self;
}

// MARK: - Tag-based (core logic)

+ (nullable TagPictureRef *)readFromTag:(nonnull void *)opaqueTag {
    Tag *tag = static_cast<Tag *>(opaqueTag);

    auto pictures = tag->complexProperties(pictureKey);
    if (pictures.isEmpty())
        return nil;

    // take the first picture only
    auto picture = pictures.front();

    String pictureMimeType = picture.value(mimeTypeKey).value<String>();
    NSString *mimeType = StringUtil::utf8NSString(pictureMimeType);
    UTType *utType = [UTType typeWithMIMEType:mimeType];

    if (!utType)
        return nil;

    ByteVector pictureData = picture.value(dataKey).toByteVector();
    NSData *nsData = [[NSData alloc] initWithBytes:pictureData.data() length:pictureData.size()];
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)nsData);

    CGImageRef imageRef = NULL;

    if (utType == UTTypeJPEG) {
        imageRef = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    } else if (utType == UTTypePNG) {
        imageRef = CGImageCreateWithPNGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    }

    CFRelease(dataProvider);

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
    // TagPictureRef retains, so release the local +1 from CGImageCreate
    CGImageRelease(imageRef);

    return pictureRef;
}

+ (bool)write:(nullable TagPictureRef *)picture toTag:(nonnull void *)opaqueTag {
    Tag *tag = static_cast<Tag *>(opaqueTag);

    if (!picture) {
        tag->setComplexProperties(pictureKey, {});
        return true;
    }

    VariantMap map;

    if (picture.pictureDescription) {
        const char *value = StringUtil::utf8CString(picture.pictureDescription);
        map.insert(descriptionKey, String(value, String::Type::UTF8));
    }

    if (picture.pictureType) {
        const char *value = StringUtil::utf8CString(picture.pictureType);
        map.insert(pictureTypeKey, String(value, String::Type::UTF8));
    }

    NSString *mimeType = picture.utType.preferredMIMEType;
    const char *value = StringUtil::utf8CString(mimeType);
    map.insert(mimeTypeKey, String(value, String::Type::UTF8));

    CFMutableDataRef mutableData = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef destination =
        CGImageDestinationCreateWithData(mutableData, (__bridge CFStringRef)picture.utType.identifier, 1, NULL);

    if (!destination) {
        CFRelease(mutableData);
        return false;
    }

    CGImageDestinationAddImage(destination, picture.cgImage, NULL);

    if (!CGImageDestinationFinalize(destination)) {
        CFRelease(destination);
        CFRelease(mutableData);
        return false;
    }

    NSData *nsData = (__bridge NSData *)mutableData;

    if (!nsData) {
        CFRelease(destination);
        CFRelease(mutableData);
        return false;
    }

    const char *bytes = (const char *)[nsData bytes];
    NSUInteger length = [nsData length];
    vector<char> vec(length);
    copy(bytes, bytes + length, vec.begin());

    ByteVector data = ByteVector(vec.data(), int(vec.size()));
    map.insert(dataKey, data);

    tag->setComplexProperties(pictureKey, {map});

    CFRelease(destination);
    CFRelease(mutableData);

    return true;
}

// MARK: - Path-based (thin wrappers)
//
// The path-based methods route through FileRef::complexProperties /
// setComplexProperties rather than Tag::complexProperties so that
// format-specific picture implementations are honoured. The most
// important case is FLAC: TagLib stores cover art in native
// METADATA_BLOCK_PICTURE blocks at the FLAC::File level, NOT inside
// the XiphComment that fileRef.tag() returns. Going through the
// FileRef dispatch table picks up FLAC's PICTURE blocks, ID3v2 APIC
// frames, MP4 'covr' atoms, etc., uniformly.

// Build a TagPictureRef from a decoded picture variant map. Shared between
// the Tag-based core path and the FileRef-based path-based path.
static TagPictureRef *_Nullable buildPictureRef(const VariantMap &picture) {
    String pictureMimeType = picture.value(mimeTypeKey).value<String>();
    NSString *mimeType = StringUtil::utf8NSString(pictureMimeType);
    UTType *utType = [UTType typeWithMIMEType:mimeType];

    if (!utType)
        return nil;

    ByteVector pictureData = picture.value(dataKey).toByteVector();
    NSData *nsData = [[NSData alloc] initWithBytes:pictureData.data() length:pictureData.size()];
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)nsData);

    CGImageRef imageRef = NULL;

    if (utType == UTTypeJPEG) {
        imageRef = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    } else if (utType == UTTypePNG) {
        imageRef = CGImageCreateWithPNGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    }

    CFRelease(dataProvider);

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
    CGImageRelease(imageRef);
    return pictureRef;
}

// Encode a TagPictureRef into a VariantMap suitable for setComplexProperties.
// Returns true on success.
static bool encodePicture(TagPictureRef *picture, VariantMap &outMap) {
    if (picture.pictureDescription) {
        const char *value = StringUtil::utf8CString(picture.pictureDescription);
        outMap.insert(descriptionKey, String(value, String::Type::UTF8));
    }

    if (picture.pictureType) {
        const char *value = StringUtil::utf8CString(picture.pictureType);
        outMap.insert(pictureTypeKey, String(value, String::Type::UTF8));
    }

    NSString *mimeType = picture.utType.preferredMIMEType;
    const char *value = StringUtil::utf8CString(mimeType);
    outMap.insert(mimeTypeKey, String(value, String::Type::UTF8));

    CFMutableDataRef mutableData = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef destination =
        CGImageDestinationCreateWithData(mutableData, (__bridge CFStringRef)picture.utType.identifier, 1, NULL);

    if (!destination) {
        CFRelease(mutableData);
        return false;
    }

    CGImageDestinationAddImage(destination, picture.cgImage, NULL);

    if (!CGImageDestinationFinalize(destination)) {
        CFRelease(destination);
        CFRelease(mutableData);
        return false;
    }

    NSData *nsData = (__bridge NSData *)mutableData;

    const char *bytes = (const char *)[nsData bytes];
    NSUInteger length = [nsData length];
    vector<char> vec(length);
    copy(bytes, bytes + length, vec.begin());

    ByteVector data = ByteVector(vec.data(), int(vec.size()));
    outMap.insert(dataKey, data);

    CFRelease(destination);
    CFRelease(mutableData);
    return true;
}

- (nullable instancetype)initWithPath:(nonnull NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return NULL;
    }

    auto pictures = fileRef.complexProperties(pictureKey);
    if (pictures.isEmpty())
        return NULL;

    TagPictureRef *ref = buildPictureRef(pictures.front());
    if (!ref)
        return NULL;

    self = [super init];
    _pictureRef = ref;
    return self;
}

+ (bool)write:(TagPictureRef *)picture path:(nonnull NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    if (!picture) {
        fileRef.setComplexProperties(pictureKey, {});
        fileRef.save();
        return true;
    }

    VariantMap map;
    if (!encodePicture(picture, map))
        return false;

    fileRef.setComplexProperties(pictureKey, {map});
    fileRef.save();
    return true;
}

@end
