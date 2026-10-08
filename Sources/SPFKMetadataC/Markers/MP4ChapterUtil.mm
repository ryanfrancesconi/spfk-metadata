// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <cmath>

#import <taglib/mp4chapter.h>
#import <taglib/mp4file.h>

#import "ChapterMarker.h"
#import "MP4ChapterUtil.h"
#import "FileSave.h"

using namespace TagLib;

// MARK: - Helpers

/// Chapter times are milliseconds.
static long long secondsToChapterTime(NSTimeInterval seconds) {
    return static_cast<long long>(round(seconds * 1000.0));
}

static NSTimeInterval chapterTimeToSeconds(long long chapterTime) {
    return static_cast<NSTimeInterval>(chapterTime) / 1000.0;
}

// MARK: - MP4ChapterUtil

@implementation MP4ChapterUtil

+ (NSArray *)read:(NSString *)path {
    MP4::File file(path.UTF8String);

    if (!file.isOpen() || !file.isValid()) {
        return nil;
    }

    // QuickTime chapter track first, then Nero chpl.
    MP4::ChapterList chapters = file.qtChapters();

    if (chapters.isEmpty()) {
        chapters = file.neroChapters();
    }

    if (chapters.isEmpty()) {
        return nil;
    }

    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (auto it = chapters.begin(); it != chapters.end(); ++it) {
        NSTimeInterval startTime = chapterTimeToSeconds(it->startTime());
        NSString *name = @(it->title().toCString(true));

        NSTimeInterval endTime = 0;
        auto next = it;
        ++next;

        if (next != chapters.end()) {
            endTime = chapterTimeToSeconds(next->startTime());
        }

        ChapterMarker *marker = [[ChapterMarker alloc] initWithName:name startTime:startTime endTime:endTime];
        [array addObject:marker];
    }

    return array.count > 0 ? array : nil;
}

+ (bool)write:(NSArray *)chapters to:(NSString *)path {
    MP4::File file(path.UTF8String);

    if (!file.isOpen() || !file.isValid()) {
        return false;
    }

    return [self write:chapters toFile:&file] && FileSave::save(&file);
}

+ (bool)write:(NSArray *)chapters toFile:(void *)opaqueFile {
    auto *file = dynamic_cast<MP4::File *>(static_cast<TagLib::File *>(opaqueFile));

    if (!file) {
        return false;
    }

    MP4::ChapterList chapterList;

    for (ChapterMarker *marker in chapters) {
        String title;

        if (marker.name.length > 0) {
            title = String(marker.name.UTF8String, String::UTF8);
        }

        // Neither the QuickTime track nor Nero chpl stores an end time.
        chapterList.append(MP4::Chapter(title, secondsToChapterTime(marker.startTime)));
    }

    // A Nero list left beside the new track would disagree with it, and the reader falls back to it
    // when the track is empty.
    file->setQtChapters(chapterList);
    file->setNeroChapters(MP4::ChapterList());
    return true;
}

+ (bool)remove:(NSString *)path {
    MP4::File file(path.UTF8String);

    if (!file.isOpen() || !file.isValid()) {
        return false;
    }

    file.setQtChapters(MP4::ChapterList());
    file.setNeroChapters(MP4::ChapterList());
    return FileSave::save(&file);
}

@end
