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
#import "TagFileType.h"
#import "TagLibBridge.h"
#import "TagPictureRef.h"

#import "StringUtil.h"

using namespace std;
using namespace TagLib;

@implementation TagLibBridge

+ (nullable NSDictionary *)getProperties:(NSString *)path {
    TagFile *tagFile = [[TagFile alloc] initWithPath:path];

    if (![tagFile load]) {
        return NULL;
    }

    return tagFile.dictionary;
}

+ (bool)setProperties:(NSString *)path
           dictionary:(NSDictionary *)dictionary {
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

    return @(tag->title().toCString());
}

+ (bool)setTitle:(NSString *)path
           title:(NSString *)title {
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

    tag->setTitle(title.UTF8String);

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

    return @(tag->comment().toCString());
}

+ (bool)setComment:(NSString *)path
           comment:(NSString *)comment {
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

    tag->setComment(comment.UTF8String);

    return fileRef.save();
}

+ (bool)removeAllTags:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        cout << "Unable to read path: " << path.UTF8String << endl;
        return false;
    }

    NSString *fileType = [TagFileType detectType:path];

    // implementation for strip() is specific to each type of file

    bool stripped = false;

    if ([fileType isEqualToString:kTagFileTypeWave]) {
        auto *f = dynamic_cast<RIFF::WAV::File *>(fileRef.file());
        if (f) { f->strip(); stripped = true; }
    } else if ([fileType isEqualToString:kTagFileTypeM4a] || [fileType isEqualToString:kTagFileTypeMp4]) {
        auto *f = dynamic_cast<MP4::File *>(fileRef.file());
        if (f) { f->strip(); stripped = true; }
    } else if ([fileType isEqualToString:kTagFileTypeMp3]) {
        auto *f = dynamic_cast<MPEG::File *>(fileRef.file());
        if (f) { f->strip(); stripped = true; }
    } else if ([fileType isEqualToString:kTagFileTypeFlac]) {
        auto *f = dynamic_cast<FLAC::File *>(fileRef.file());
        if (f) { f->strip(); stripped = true; }
    }

    if (!stripped) {
        cout << "Resetting property map for " << path.UTF8String << endl;
        fileRef.setProperties(PropertyMap());
    }

    return fileRef.save();
}

+ (bool)copyTagsFromPath:(NSString *)path
                  toPath:(NSString *)toPath {
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

    output.tag()->setProperties(tags);

    return output.save();
}

@end
