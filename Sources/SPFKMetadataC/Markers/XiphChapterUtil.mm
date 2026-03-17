// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

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
#import "XiphChapterUtil.h"

using namespace std;
using namespace TagLib;

// MARK: - Helpers

/// Returns the XiphComment for a file opened via FileRef, or nullptr if unsupported.
/// For FLAC files, creates the XiphComment if `create` is true.
static Ogg::XiphComment *getXiphComment(TagLib::File *file, bool create = false) {
    if (auto *flac = dynamic_cast<FLAC::File *>(file)) {
        return flac->xiphComment(create);
    }

    if (auto *vorbis = dynamic_cast<Ogg::Vorbis::File *>(file)) {
        return vorbis->tag();
    }

    if (auto *opus = dynamic_cast<Ogg::Opus::File *>(file)) {
        return opus->tag();
    }

    return nullptr;
}

/// Formats a time interval as HH:MM:SS.mmm
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

/// Formats a chapter field key: CHAPTER000, CHAPTER001, etc.
static String chapterKey(int index) {
    char buf[16];
    snprintf(buf, sizeof(buf), "CHAPTER%03d", index);
    return String(buf);
}

/// Formats a chapter name field key: CHAPTER000NAME, CHAPTER001NAME, etc.
static String chapterNameKey(int index) {
    char buf[20];
    snprintf(buf, sizeof(buf), "CHAPTER%03dNAME", index);
    return String(buf);
}

/// Removes all CHAPTER* fields from a XiphComment.
/// We must collect keys first, then remove, to avoid mutating during iteration.
static void removeAllChapterFields(Ogg::XiphComment *comment) {
    vector<String> keysToRemove;

    const auto &fields = comment->fieldListMap();

    for (auto it = fields.begin(); it != fields.end(); ++it) {
        string key = it->first.to8Bit();

        if (key.find("CHAPTER") == 0) {
            keysToRemove.push_back(it->first);
        }
    }

    for (const auto &key : keysToRemove) {
        comment->removeFields(key);
    }
}

// MARK: - XiphChapterUtil

@implementation XiphChapterUtil

+ (NSArray *)getChapters:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return nil;
    }

    Ogg::XiphComment *comment = getXiphComment(fileRef.file());

    if (!comment) {
        return nil;
    }

    const auto &fields = comment->fieldListMap();

    // Collect chapter indices by scanning for CHAPTER\d{3} keys (not NAME keys)
    vector<int> indices;

    for (auto it = fields.begin(); it != fields.end(); ++it) {
        string key = it->first.to8Bit();

        // Match CHAPTER followed by exactly 3 digits (no suffix)
        if (key.length() == 10 && key.find("CHAPTER") == 0) {
            string numStr = key.substr(7, 3);

            // Verify all digits
            if (isdigit(numStr[0]) && isdigit(numStr[1]) && isdigit(numStr[2])) {
                indices.push_back(stoi(numStr));
            }
        }
    }

    if (indices.empty()) {
        return nil;
    }

    sort(indices.begin(), indices.end());

    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (size_t i = 0; i < indices.size(); i++) {
        int idx = indices[i];
        String timeKey = chapterKey(idx);
        String nameKey = chapterNameKey(idx);

        // Parse timestamp
        auto timeIt = fields.find(timeKey);

        if (timeIt == fields.end() || timeIt->second.isEmpty()) {
            continue;
        }

        string tsStr = timeIt->second.front().to8Bit();
        NSTimeInterval startTime = parseTimestamp(tsStr);

        if (startTime < 0) {
            continue;
        }

        // Get name (optional)
        NSString *name = @"";
        auto nameIt = fields.find(nameKey);

        if (nameIt != fields.end() && !nameIt->second.isEmpty()) {
            name = @(nameIt->second.front().toCString(true));
        }

        // endTime = next chapter's start time, or 0 for the last
        NSTimeInterval endTime = 0;

        if (i + 1 < indices.size()) {
            String nextTimeKey = chapterKey(indices[i + 1]);
            auto nextIt = fields.find(nextTimeKey);

            if (nextIt != fields.end() && !nextIt->second.isEmpty()) {
                endTime = parseTimestamp(nextIt->second.front().to8Bit());

                if (endTime < 0) {
                    endTime = 0;
                }
            }
        }

        ChapterMarker *marker = [[ChapterMarker alloc] initWithName:name
                                                           startTime:startTime
                                                             endTime:endTime];
        [array addObject:marker];
    }

    return array.count > 0 ? array : nil;
}

+ (bool)update:(NSString *)path chapters:(NSArray *)chapters {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    Ogg::XiphComment *comment = getXiphComment(fileRef.file(), /* create */ true);

    if (!comment) {
        return false;
    }

    // Remove existing chapter fields
    removeAllChapterFields(comment);

    // Write new chapter fields
    int index = 0;

    for (ChapterMarker *marker in chapters) {
        String timeKey = chapterKey(index);
        String nameKey = chapterNameKey(index);

        string timestamp = formatTimestamp(marker.startTime);
        comment->addField(timeKey, String(timestamp));

        if (marker.name.length > 0) {
            comment->addField(nameKey, String(marker.name.UTF8String));
        }

        index++;
    }

    return fileRef.save();
}

+ (bool)removeAllChapters:(NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    Ogg::XiphComment *comment = getXiphComment(fileRef.file());

    if (!comment) {
        return false;
    }

    removeAllChapterFields(comment);

    return fileRef.save();
}

@end
