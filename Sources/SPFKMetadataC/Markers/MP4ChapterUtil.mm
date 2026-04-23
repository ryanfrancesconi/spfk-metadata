// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <cmath>

#import <taglib/mp4file.h>
#import <taglib/mp4chapter.h>

#import "ChapterMarker.h"
#import "MP4ChapterUtil.h"

using namespace TagLib;

// MARK: - Helpers

/// Converts seconds to chapter time units (milliseconds).
static long long secondsToChapterTime(NSTimeInterval seconds) {
    return static_cast<long long>(round(seconds * 1000.0));
}

/// Converts chapter time units (milliseconds) to seconds.
static NSTimeInterval chapterTimeToSeconds(long long chapterTime) {
    return static_cast<NSTimeInterval>(chapterTime) / 1000.0;
}

// MARK: - MP4ChapterUtil

@implementation MP4ChapterUtil

+ (NSArray *)chaptersIn:(NSString *)path {
    MP4::File file(path.UTF8String);

    if (!file.isOpen() || !file.isValid()) {
        return nil;
    }

    // Try QuickTime chapter track first, fall back to Nero chpl
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

        // endTime = next chapter's start time, or 0 for the last
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

+ (bool)writeChapters:(NSArray *)chapters to:(NSString *)path {
    MP4::ChapterList chapterList;

    for (ChapterMarker *marker in chapters) {
        String title;

        if (marker.name.length > 0) {
            title = String(marker.name.UTF8String, String::UTF8);
        }

        chapterList.append(MP4::Chapter(title, secondsToChapterTime(marker.startTime)));
    }

    MP4::File file(path.UTF8String);

    if (!file.isOpen() || !file.isValid()) {
        return false;
    }

    file.setQtChapters(chapterList);
    return file.save();
}

+ (bool)removeChaptersIn:(NSString *)path {
    MP4::File file(path.UTF8String);

    if (!file.isOpen() || !file.isValid()) {
        return false;
    }

    // Remove both QT chapter track and Nero chpl (if present)
    file.setQtChapters(MP4::ChapterList());
    file.setNeroChapters(MP4::ChapterList());
    return file.save();
}

@end
