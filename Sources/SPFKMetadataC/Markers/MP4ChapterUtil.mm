// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <cmath>

#import <taglib/mp4chapterlist.h>

#import "ChapterMarker.h"
#import "MP4ChapterUtil.h"

using namespace TagLib;

// MARK: - Helpers

/// Converts seconds to Nero chpl time units (100-nanosecond intervals).
static long long secondsToChplTime(NSTimeInterval seconds) {
    return static_cast<long long>(round(seconds * 10000000.0));
}

/// Converts Nero chpl time units (100-nanosecond intervals) to seconds.
static NSTimeInterval chplTimeToSeconds(long long chplTime) {
    return static_cast<NSTimeInterval>(chplTime) / 10000000.0;
}

// MARK: - MP4ChapterUtil

@implementation MP4ChapterUtil

+ (NSArray *)chaptersIn:(NSString *)path {
    MP4::ChapterList chapters = MP4::MP4ChapterList::read(path.UTF8String);

    if (chapters.isEmpty()) {
        return nil;
    }

    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (auto it = chapters.begin(); it != chapters.end(); ++it) {
        NSTimeInterval startTime = chplTimeToSeconds(it->startTime);
        NSString *name = @(it->title.toCString(true));

        // endTime = next chapter's start time, or 0 for the last
        NSTimeInterval endTime = 0;
        auto next = it;
        ++next;

        if (next != chapters.end()) {
            endTime = chplTimeToSeconds(next->startTime);
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
        ch.startTime = secondsToChplTime(marker.startTime);

        if (marker.name.length > 0) {
            ch.title = String(marker.name.UTF8String, String::UTF8);
        }

        chapterList.append(ch);
    }

    return MP4::MP4ChapterList::write(path.UTF8String, chapterList);
}

+ (bool)removeChaptersIn:(NSString *)path {
    return MP4::MP4ChapterList::remove(path.UTF8String);
}

@end
