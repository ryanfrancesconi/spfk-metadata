// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <iostream>
#import <vector>

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

// MARK: - TagLib string constants

static const auto pictureKey = String("PICTURE");
static const auto dataKey = String("data");
static const auto mimeTypeKey = String("mimeType");
static const auto descriptionKey = String("description");
static const auto pictureTypeKey = String("pictureType");

// MARK: - Static helpers

/// Decode a single picture VariantMap into a TagPictureRef. Single source of
/// truth for picture decoding across all read sites.
static TagPictureRef *_Nullable buildPictureRef(const VariantMap &picture) {
    String pictureMimeType = picture.value(mimeTypeKey).value<String>();
    NSString *mimeType = StringUtil::utf8NSString(pictureMimeType);
    UTType *utType = [UTType typeWithMIMEType:mimeType];
    // MP4 CoverArt::Unknown format produces a bare "image/" MIME type that the OS
    // cannot resolve to a UTType. Fall back to JPEG so CGImageSource can still
    // probe and decode the actual bytes below.
    if (!utType) {
        utType = [UTType typeWithIdentifier:@"public.jpeg"];
    }

    ByteVector pictureData = picture.value(dataKey).toByteVector();
    NSData *nsData = [[NSData alloc] initWithBytes:pictureData.data() length:pictureData.size()];

    CGImageRef imageRef = NULL;

    // Generic path: handles JPEG, PNG, WebP, HEIC, TIFF, GIF, etc.
    {
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)nsData, NULL);
        if (source) {
            imageRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
            CFRelease(source);
        }
    }

    // JPEG fallback for marginal-but-decodable input that CGImageSource may reject.
    if (!imageRef) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)nsData);
        if (provider) {
            imageRef = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
            CFRelease(provider);
        }
    }

    // PNG fallback for the same reason.
    if (!imageRef) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)nsData);
        if (provider) {
            imageRef = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
            CFRelease(provider);
        }
    }

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
    // TagPictureRef retains, so release the local +1 from CGImageCreate/CGImageSourceCreate
    CGImageRelease(imageRef);

    return pictureRef;
}

/// Encode a CGImage to NSData using the given UTType identifier.
/// Returns nil if the format is unsupported or encoding fails.
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

/// Encode a TagPictureRef into a picture VariantMap for setComplexProperties.
/// Falls back to JPEG if the source format cannot be written by CGImageDestination.
/// Returns true on success.
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
        // Fall back to JPEG for formats CGImageDestination cannot write (e.g. WebP).
        encodeType = [UTType typeWithIdentifier:@"public.jpeg"];
        encoded = tryEncodeImage(picture.cgImage, encodeType.identifier);
    }

    if (!encoded)
        return false;

    NSString *mimeType = encodeType.preferredMIMEType;
    const char *mimeValue = StringUtil::utf8CString(mimeType);
    outMap.insert(mimeTypeKey, String(mimeValue, String::Type::UTF8));

    const char *bytes = (const char *)[encoded bytes];
    NSUInteger length = [encoded length];
    vector<char> vec(length);
    copy(bytes, bytes + length, vec.begin());

    outMap.insert(dataKey, ByteVector(vec.data(), int(vec.size())));
    return true;
}

/// Read fallback: when FileRef::complexProperties("PICTURE") is empty for a
/// FLAC, look in the XiphComment for legacy METADATA_BLOCK_PICTURE/COVERART
/// entries written by older versions of spfk-metadata.
static List<VariantMap> flacXiphCommentPictureFallback(FileRef &fileRef) {
    if (auto *flac = dynamic_cast<FLAC::File *>(fileRef.file())) {
        if (auto *xiph = flac->xiphComment()) {
            return xiph->complexProperties(pictureKey);
        }
    }
    return {};
}

/// Write hygiene: after writing native FLAC PICTURE blocks via
/// FileRef::setComplexProperties, strip any legacy XiphComment picture
/// entries so the file ends up with exactly one copy of the artwork in
/// the canonical native location.
static void clearLegacyFlacXiphCommentPictures(FileRef &fileRef) {
    if (auto *flac = dynamic_cast<FLAC::File *>(fileRef.file())) {
        if (auto *xiph = flac->xiphComment()) {
            // METADATA_BLOCK_PICTURE and COVERART are stored in the XiphComment's
            // internal pictureList (not fieldListMap), so removeAllPictures() is
            // the correct API. removeFields() has no effect on picture entries.
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

    // For FLAC files that stored artwork via the old XiphComment path,
    // fall back to reading from the XiphComment directly.
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

    if (!picture) {
        fileRef.setComplexProperties(pictureKey, {});
        clearLegacyFlacXiphCommentPictures(fileRef);
        fileRef.save();
        return true;
    }

    VariantMap map;
    if (!encodePicture(picture, map))
        return false;

    fileRef.setComplexProperties(pictureKey, {map});
    clearLegacyFlacXiphCommentPictures(fileRef);
    fileRef.save();
    return true;
}

@end
