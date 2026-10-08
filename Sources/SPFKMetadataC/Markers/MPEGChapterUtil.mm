// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <iomanip>
#import <iostream>
#import <stdio.h>

#import <taglib/chapterframe.h>
#import <taglib/fileref.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/tableofcontentsframe.h>
#import <taglib/tag.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>

#import "ChapterMarker.h"
#import "MPEGChapterUtil.h"
#import <StringUtil.h>

using namespace std;
using namespace TagLib;

/// A Latin-1 frame whose bytes are valid UTF-8 is read as UTF-8, which is how titles written before
/// UTF-8 frames are stored. Genuine Latin-1 text that is also valid UTF-8 is misread; it is rare.
static NSString *chapterTitle(const ID3v2::TextIdentificationFrame *frame) {
    String text = frame->toString();

    if (frame->textEncoding() == String::Latin1) {
        ByteVector bytes = text.data(String::Latin1);
        NSString *utf8 = [[NSString alloc] initWithBytes:bytes.data()
                                                  length:bytes.size()
                                                encoding:NSUTF8StringEncoding];
        if (utf8)
            return utf8;
    }

    return @(text.toCString(true));
}

/// UTF-8 when the bytes are valid UTF-8, Latin-1 otherwise.
static NSString *elementIDName(const ByteVector &elementID) {
    NSString *utf8 = [[NSString alloc] initWithBytes:elementID.data()
                                              length:elementID.size()
                                            encoding:NSUTF8StringEncoding];
    if (utf8)
        return utf8;

    return @(String(elementID, String::Latin1).toCString(true));
}

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
        // A compressed or encrypted CHAP is listed as an UnknownFrame TagLib could not decode.
        ID3v2::ChapterFrame *frame = dynamic_cast<ID3v2::ChapterFrame *>(*it);

        if (!frame) {
            continue;
        }

        NSTimeInterval startTime = NSTimeInterval(frame->startTime()) / 1000;
        NSTimeInterval endTime = NSTimeInterval(frame->endTime()) / 1000;

        // The element ID stands in until an embedded TIT2 names the chapter.
        NSString *chapterName = elementIDName(frame->elementID());

        for (auto it = frame->embeddedFrameList().begin(); it != frame->embeddedFrameList().end(); ++it) {
            auto tit2Frame = dynamic_cast<const ID3v2::TextIdentificationFrame *>(*it);

            if (tit2Frame && tit2Frame->frameID() == "TIT2") {
                chapterName = chapterTitle(tit2Frame);
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

    return [self write:chapters toFile:fileRef.file()] && fileRef.save();
}

+ (bool)write:(NSArray *)chapters toFile:(void *)opaqueFile {
    MPEG::File *mpegFile = dynamic_cast<MPEG::File *>(static_cast<File *>(opaqueFile));

    if (!mpegFile) {
        cout << "setMP3Chapters: Not a MPEG File" << endl;
        return false;
    }

    // The table of contents lists element IDs, so it is rebuilt with the chapters it indexes.
    mpegFile->ID3v2Tag()->removeFrames("CHAP");
    mpegFile->ID3v2Tag()->removeFrames("CTOC");

    ID3v2::Header header;
    ByteVectorList elementIDs;

    for (ChapterMarker *object in chapters) {
        ID3v2::ChapterFrame *chapter = new ID3v2::ChapterFrame(&header, "CHAP");
        chapter->setStartTime(object.startTime * 1000);
        chapter->setEndTime(object.endTime * 1000);

        // Numbered, so two chapters with one name still have distinct IDs; the name is the TIT2.
        const ByteVector elementID = String("chp" + to_string(elementIDs.size()), String::Latin1).data(String::Latin1);
        chapter->setElementID(elementID);
        elementIDs.append(elementID);

        const char *cname = object.name ? object.name.UTF8String : "";

        // Rendered as UTF-16 instead if the tag is ever written as ID3v2.3.
        ID3v2::TextIdentificationFrame *titleFrame = new ID3v2::TextIdentificationFrame("TIT2", String::UTF8);
        titleFrame->setText(String(cname, String::UTF8));
        chapter->addEmbeddedFrame(titleFrame);
        mpegFile->ID3v2Tag()->addFrame(chapter);
    }

    if (!elementIDs.isEmpty()) {
        auto *tableOfContents = new ID3v2::TableOfContentsFrame(ByteVector("toc"), elementIDs);
        tableOfContents->setIsTopLevel(true);
        tableOfContents->setIsOrdered(true);
        mpegFile->ID3v2Tag()->addFrame(tableOfContents);
    }

    return true;
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
