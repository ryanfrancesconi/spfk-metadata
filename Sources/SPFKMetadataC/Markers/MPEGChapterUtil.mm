// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <iomanip>
#import <iostream>
#import <stdio.h>

#import <taglib/chapterframe.h>
#import <taglib/fileref.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/tag.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>

#import "ChapterMarker.h"
#import "MPEGChapterUtil.h"
#import <StringUtil.h>

using namespace std;
using namespace TagLib;

@implementation MPEGChapterUtil

/// ID3v2 CHAP frames only.
+ (NSArray *)read:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return nil;
    }

    MPEG::File *file = dynamic_cast<MPEG::File *>(fileRef.file());

    if (!file || !file->hasID3v2Tag()) {
        return nil;
    }

    ID3v2::FrameList chapterList = file->ID3v2Tag()->frameList("CHAP");
    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (auto it = chapterList.begin(); it != chapterList.end(); ++it) {
        ID3v2::ChapterFrame *frame = dynamic_cast<ID3v2::ChapterFrame *>(*it);

        NSTimeInterval startTime = NSTimeInterval(frame->startTime()) / 1000;
        NSTimeInterval endTime = NSTimeInterval(frame->endTime()) / 1000;

        // The element ID stands in until an embedded TIT2 names the chapter.
        NSString *chapterName = @(String(frame->elementID()).toCString(true));

        for (auto it = frame->embeddedFrameList().begin(); it != frame->embeddedFrameList().end(); ++it) {
            auto tit2Frame = dynamic_cast<const ID3v2::TextIdentificationFrame *>(*it);

            if (tit2Frame->frameID() == "TIT2") {
                chapterName = @(tit2Frame->toString().toCString());
            }
        }

        ChapterMarker *chapterFrame = [[ChapterMarker alloc] initWithName:chapterName
                                                                startTime:startTime
                                                                  endTime:endTime];

        [array addObject:chapterFrame];
    }

    return array;
}

+ (bool)write:(NSArray *)chapters to:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    MPEG::File *mpegFile = dynamic_cast<MPEG::File *>(fileRef.file());

    if (!mpegFile) {
        cout << "setMP3Chapters: Not a MPEG File" << endl;
        return false;
    }

    mpegFile->ID3v2Tag()->removeFrames("CHAP");

    ID3v2::Header header;

    for (ChapterMarker *object in chapters) {
        ID3v2::ChapterFrame *chapter = new ID3v2::ChapterFrame(&header, "CHAP");
        chapter->setStartTime(object.startTime * 1000);
        chapter->setEndTime(object.endTime * 1000);

        const char *cname = object.name.UTF8String;
        String string = String(cname);
        chapter->setElementID(string.data(String::Type::UTF8));

        ID3v2::TextIdentificationFrame *titleFrame = new ID3v2::TextIdentificationFrame("TIT2");
        titleFrame->setText(cname);
        chapter->addEmbeddedFrame(titleFrame);
        mpegFile->ID3v2Tag()->addFrame(chapter);
    }

    return mpegFile->save();
}

+ (bool)remove:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    MPEG::File *mpegFile = dynamic_cast<MPEG::File *>(fileRef.file());

    if (!mpegFile) {
        cout << "removeMP3Chapters: Not a MPEG File" << endl;
        return false;
    }

    mpegFile->ID3v2Tag()->removeFrames("CHAP");

    return mpegFile->save();
}

@end
