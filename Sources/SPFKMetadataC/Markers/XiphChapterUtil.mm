// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <algorithm>
#import <cmath>
#import <iostream>
#import <regex>
#import <string>
#import <vector>

#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/opusfile.h>
#import <taglib/vorbisfile.h>
#import <taglib/xiphcomment.h>

#import "ChapterMarker.h"
#import "TagUtil.h"
#import "XiphChapterUtil.h"
#import "FileSave.h"

using namespace std;
using namespace TagLib;

// MARK: - Helpers

/// HH:MM:SS.mmm
static string formatTimestamp(NSTimeInterval seconds) {
    int totalMs = static_cast<int>(round(seconds * 1000));
    int h = totalMs / 3600000;
    int m = (totalMs % 3600000) / 60000;
    int s = (totalMs % 60000) / 1000;
    int ms = totalMs % 1000;

    char buf[16];
    snprintf(buf, sizeof(buf), "%02d:%02d:%02d.%03d", h, m, s, ms);
    return string(buf);
}

/// Parses HH:MM:SS.mmm into seconds, or -1 on failure.
static NSTimeInterval parseTimestamp(const string &ts) {
    int h = 0, m = 0, s = 0, ms = 0;

    if (sscanf(ts.c_str(), "%d:%d:%d.%d", &h, &m, &s, &ms) < 3) {
        return -1;
    }

    return h * 3600.0 + m * 60.0 + s + ms / 1000.0;
}

/// CHAPTER000, or with a suffix CHAPTER000NAME, CHAPTER000END.
static String chapterKey(int index, const char *suffix = "") {
    char buf[20];
    snprintf(buf, sizeof(buf), "CHAPTER%03d%s", index, suffix);
    return String(buf);
}

/// The field's first value as a timestamp, or -1 when absent or malformed.
static NSTimeInterval timestampField(const Ogg::FieldListMap &fields, const String &key) {
    auto it = fields.find(key);

    if (it == fields.end() || it->second.isEmpty()) {
        return -1;
    }

    return parseTimestamp(it->second.front().to8Bit());
}

/// The CHAPTERnnn start-time keys, sorted by index: the index and the digits as written. Other tools
/// write more than three digits; nine at most fit an int.
static vector<pair<int, string>> chapterIndices(const Ogg::FieldListMap &fields) {
    vector<pair<int, string>> indices;

    for (auto it = fields.begin(); it != fields.end(); ++it) {
        string key = it->first.to8Bit();

        if (key.find("CHAPTER") != 0)
            continue;

        string digits = key.substr(7);

        if (digits.length() < 3 || digits.length() > 9 ||
            !all_of(digits.begin(), digits.end(), [](unsigned char c) { return isdigit(c); }))
            continue;

        indices.emplace_back(stoi(digits), digits);
    }

    stable_sort(indices.begin(), indices.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
    return indices;
}

/// Removes every chapter field. Keys are collected first, since removal invalidates the iteration.
static void removeAllChapterFields(Ogg::XiphComment *comment) {
    vector<String> keysToRemove;

    const auto &fields = comment->fieldListMap();

    for (auto it = fields.begin(); it != fields.end(); ++it) {
        if (TagUtil::isChapterField(it->first)) {
            keysToRemove.push_back(it->first);
        }
    }

    for (const auto &key : keysToRemove) {
        comment->removeFields(key);
    }
}

// MARK: - XiphChapterUtil

@implementation XiphChapterUtil

+ (NSArray *)read:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return nil;
    }

    Ogg::XiphComment *comment = TagUtil::xiphComment(fileRef.file());

    if (!comment) {
        return @[];
    }

    const auto &fields = comment->fieldListMap();
    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (const auto &[idx, digits] : chapterIndices(fields)) {
        const String key("CHAPTER" + digits);
        NSTimeInterval startTime = timestampField(fields, key);

        if (startTime < 0) {
            continue;
        }

        NSString *name = @"";
        auto nameIt = fields.find(key + "NAME");

        if (nameIt != fields.end() && !nameIt->second.isEmpty()) {
            name = @(nameIt->second.front().toCString(true));
        }

        // END is written only for regions, so a chapter without one reads back as a point: giving
        // it the next chapter's start would have the next save write it as a region.
        NSTimeInterval endTime = max(timestampField(fields, key + "END"), startTime);

        ChapterMarker *marker = [[ChapterMarker alloc] initWithName:name startTime:startTime endTime:endTime];
        [array addObject:marker];
    }

    return array;
}

+ (bool)write:(NSArray *)chapters to:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    return [self write:chapters toFile:fileRef.file()] && FileSave::save(fileRef.file());
}

+ (bool)write:(NSArray *)chapters toFile:(void *)opaqueFile {
    // CHAPTER000 to CHAPTER999: readers take three digits, so a fourth would rename an earlier chapter.
    if (chapters.count > 1000) {
        return false;
    }

    Ogg::XiphComment *comment = TagUtil::xiphComment(static_cast<File *>(opaqueFile), /* create */ true);

    if (!comment) {
        return false;
    }

    removeAllChapterFields(comment);

    int index = 0;

    for (ChapterMarker *marker in chapters) {
        comment->addField(chapterKey(index), String(formatTimestamp(marker.startTime)));

        if (marker.name.length > 0) {
            comment->addField(chapterKey(index, "NAME"), String(marker.name.UTF8String, String::UTF8));
        }

        if (marker.endTime > marker.startTime) {
            comment->addField(chapterKey(index, "END"), String(formatTimestamp(marker.endTime)));
        }

        index++;
    }

    return true;
}

+ (bool)remove:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    Ogg::XiphComment *comment = TagUtil::xiphComment(fileRef.file());

    if (!comment) {
        return false;
    }

    removeAllChapterFields(comment);

    return FileSave::save(fileRef.file());
}

@end
