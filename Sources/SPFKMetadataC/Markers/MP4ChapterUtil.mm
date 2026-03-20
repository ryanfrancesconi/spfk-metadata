// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <cmath>

#import <taglib/mp4chapterlist.h>
#import <taglib/mp4qtchapterlist.h>

#import "ChapterMarker.h"
#import "MP4ChapterUtil.h"

using namespace TagLib;

// MARK: - Helpers

/// Converts seconds to chapter time units (100-nanosecond intervals).
static long long secondsToChapterTime(NSTimeInterval seconds) {
    return static_cast<long long>(round(seconds * 10000000.0));
}

/// Converts chapter time units (100-nanosecond intervals) to seconds.
static NSTimeInterval chapterTimeToSeconds(long long chapterTime) {
    return static_cast<NSTimeInterval>(chapterTime) / 10000000.0;
}

// MARK: - MP4ChapterUtil

@implementation MP4ChapterUtil

+ (NSArray *)chaptersIn:(NSString *)path {
    // Try QuickTime chapter track first, fall back to Nero chpl
    MP4::ChapterList chapters = MP4::MP4QTChapterList::read(path.UTF8String);

    if (chapters.isEmpty()) {
        chapters = MP4::MP4ChapterList::read(path.UTF8String);
    }

    if (chapters.isEmpty()) {
        return nil;
    }

    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (auto it = chapters.begin(); it != chapters.end(); ++it) {
        NSTimeInterval startTime = chapterTimeToSeconds(it->startTime);
        NSString *name = @(it->title.toCString(true));

        // endTime = next chapter's start time, or 0 for the last
        NSTimeInterval endTime = 0;
        auto next = it;
        ++next;

        if (next != chapters.end()) {
            endTime = chapterTimeToSeconds(next->startTime);
        }

        ChapterMarker *marker = [[ChapterMarker alloc] initWithName:name startTime:startTime endTime:endTime];
        [array addObject:marker];
    }

    return array.count > 0 ? array : nil;
}

+ (bool)writeChapters:(NSArray *)chapters to:(NSString *)path {
    MP4::ChapterList chapterList;

    for (ChapterMarker *marker in chapters) {
        MP4::Chapter ch;
        ch.startTime = secondsToChapterTime(marker.startTime);

        if (marker.name.length > 0) {
            ch.title = String(marker.name.UTF8String, String::UTF8);
        }

        chapterList.append(ch);
    }

    return MP4::MP4QTChapterList::write(path.UTF8String, chapterList);
}

+ (bool)removeChaptersIn:(NSString *)path {
    // Remove both QT chapter track and Nero chpl (if present)
    bool qtOk = MP4::MP4QTChapterList::remove(path.UTF8String);
    bool neroOk = MP4::MP4ChapterList::remove(path.UTF8String);
    return qtOk && neroOk;
}

@end
