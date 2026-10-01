// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <iomanip>
#import <iostream>
#import <stdio.h>
#import <vector>

#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <ImageIO/CGImageDestination.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/tdebuglistener.h>
#import <taglib/flacfile.h>
#import <taglib/id3v2tag.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/oggfile.h>
#import <taglib/oggflacfile.h>
#import <taglib/opusfile.h>
#import <taglib/privateframe.h>
#import <taglib/rifffile.h>
#import <taglib/tag.h>
#import <taglib/tfilestream.h>
#import <taglib/tpropertymap.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>

#import "ChapterMarker.h"
#import "TagFile.h"
#import "TagLibBridge.h"
#import "TagPictureRef.h"
#import "TagRating.h"
#import "TagRatingFile.h"

#import "StringUtil.h"
#import "TagUtil.h"
#import "WaveMarkerChunks.h"

using namespace std;
using namespace TagLib;

namespace {
    class SilentListener : public DebugListener {
    public:
        void printMessage(const String &) override {}
    };

    SilentListener silentListener;
}

@implementation TagLibBridge

+ (void)load {
    setDebugListener(&silentListener);
}

+ (nullable NSDictionary *)getProperties:(NSString *)path {
    TagFile *tagFile = [[TagFile alloc] initWithPath:path];

    if (![tagFile load]) {
        return NULL;
    }

    return tagFile.dictionary;
}

+ (bool)setProperties:(NSString *)path dictionary:(NSDictionary *)dictionary {
    TagFile *tagFile = [[TagFile alloc] initWithPath:path];

    [tagFile setDictionary:dictionary];

    return [tagFile save];
}

+ (nullable NSString *)getTitle:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        cout << "fileRef.isNull. Unable to read path: " << path.UTF8String << endl;
        return NULL;
    }

    Tag *tag = fileRef.tag();

    if (!tag) {
        return NULL;
    }

    return @(tag->title().toCString(true));
}

+ (bool)setTitle:(NSString *)path title:(NSString *)title {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << path.UTF8String << endl;
        return false;
    }

    Tag *tag = fileRef.tag();

    if (!tag) {
        cout << "Unable to create tag" << endl;
        return false;
    }

    tag->setTitle(String(title.UTF8String, String::UTF8));

    return fileRef.save();
}

+ (nullable NSString *)getComment:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << path.UTF8String << endl;
        return NULL;
    }

    Tag *tag = fileRef.tag();

    if (!tag) {
        cout << "Unable to create tag" << endl;
        return NULL;
    }

    return @(tag->comment().toCString(true));
}

+ (bool)setComment:(NSString *)path comment:(NSString *)comment {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << path.UTF8String << endl;
        return false;
    }

    Tag *tag = fileRef.tag();

    if (!tag) {
        cout << "Unable to create tag" << endl;
        return false;
    }

    tag->setComment(String(comment.UTF8String, String::UTF8));

    return fileRef.save();
}

+ (bool)removeAllTags:(NSString *)path {
    // No audio properties: stripping doesn't need them.
    FileRef fileRef(path.UTF8String, false);

    if (fileRef.isNull()) {
        cout << "Unable to read path: " << path.UTF8String << endl;
        return false;
    }

    TagUtil::clearTags(fileRef);

    return fileRef.save();
}

+ (bool)copyTagsFromPath:(NSString *)path toPath:(NSString *)toPath {
    FileRef input(path.UTF8String);

    if (input.isNull()) {
        cout << "Unable to read" << path.UTF8String << endl;
        return false;
    }

    PropertyMap tags = input.file()->properties();

    // The rating is absent from the PropertyMap — each container stores it differently
    // (ID3 POPM, the MP4 `rate` atom, Xiph RATING) — so it needs carrying separately.
    int ratingStars = TagRatingReadFromFile(input.file());

    if (tags.isEmpty() && ratingStars <= 0) {
        return true;
    }

    if (![self removeAllTags:toPath]) {
        cout << "Failed to remove tags in" << toPath.UTF8String << endl;
        return false;
    }

    FileRef output(toPath.UTF8String);

    if (output.isNull()) {
        cout << "Unable to read path: " << toPath.UTF8String << endl;
        return false;
    }

    output.file()->setProperties(tags);

    // The destination is already stripped, so its tags are saved even when the rating can't be.
    bool ratingWritten = ratingStars <= 0 || TagRatingWriteToFile(output.file(), ratingStars);

    return output.save() && ratingWritten;
}

+ (nullable NSString *)storedXMPPacket:(NSString *)path {
    ByteVector packet;

    {
        FileRef fileRef(path.UTF8String, false);
        if (fileRef.isNull()) return nil;

        if (auto *mpegFile = dynamic_cast<MPEG::File *>(fileRef.file())) {
            auto packets = mpegFile->hasID3v2Tag() ? TagUtil::xmpPrivateFrameData(mpegFile->ID3v2Tag()) : vector<ByteVector>();
            if (packets.empty()) return nil;
            packet = packets.front();
        } else if (!dynamic_cast<RIFF::WAV::File *>(fileRef.file())) {
            return nil;
        }
    }

    if (packet.isEmpty()) {
        WaveMarkerFile waveFile(path.UTF8String, false);
        if (!waveFile.isValid()) return nil;
        packet = waveFile.xmpData();
        if (packet.isEmpty()) return nil;
    }

    return [[NSString alloc] initWithBytes:packet.data() length:packet.size() encoding:NSUTF8StringEncoding];
}

+ (bool)setStoredXMPPacket:(nullable NSString *)packet path:(NSString *)path {
    const ByteVector data = packet.length > 0 ? ByteVector(packet.UTF8String) : ByteVector();
    bool isWave = false;

    {
        FileRef fileRef(path.UTF8String, false);
        if (fileRef.isNull()) return false;

        if (auto *mpegFile = dynamic_cast<MPEG::File *>(fileRef.file())) {
            if (data.isEmpty() && !mpegFile->hasID3v2Tag()) return true;

            TagUtil::setXMPPrivateFrame(mpegFile->ID3v2Tag(true), data);
            return mpegFile->save();
        }

        isWave = dynamic_cast<RIFF::WAV::File *>(fileRef.file()) != nullptr;
    }

    if (!isWave) return false;

    WaveMarkerFile waveFile(path.UTF8String, false);
    if (!waveFile.isValid() || waveFile.readOnly()) return false;

    waveFile.setXMPData(data);
    return true;
}

@end
