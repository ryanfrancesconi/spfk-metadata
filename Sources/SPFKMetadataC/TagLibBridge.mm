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

#import "StringUtil.h"

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
    // false = skip audio properties parsing (not needed for strip)
    FileRef fileRef(path.UTF8String, false);

    if (fileRef.isNull()) {
        cout << "Unable to read path: " << path.UTF8String << endl;
        return false;
    }

    // strip() implementation is specific to each file type
    File *f = fileRef.file();

    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        fp->strip();
    else if (auto *fp = dynamic_cast<MP4::File *>(f))
        fp->strip();
    else if (auto *fp = dynamic_cast<MPEG::File *>(f))
        fp->strip();
    else if (auto *fp = dynamic_cast<FLAC::File *>(f))
        fp->strip();
    else {
        cout << "Resetting property map for " << path.UTF8String << endl;
        fileRef.setProperties(PropertyMap());
    }

    return fileRef.save();
}

+ (bool)copyTagsFromPath:(NSString *)path toPath:(NSString *)toPath {
    FileRef input(path.UTF8String);

    if (input.isNull()) {
        cout << "Unable to read" << path.UTF8String << endl;
        return false;
    }

    PropertyMap tags = input.file()->properties();

    if (tags.isEmpty()) {
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

    return output.save();
}

@end
