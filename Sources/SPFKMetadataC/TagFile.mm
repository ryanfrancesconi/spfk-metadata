// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/rifffile.h>
#import <taglib/tpropertymap.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>

#import "StringUtil.h"
#import "TagAudioPropertiesC.h"
#import "TagUtil.h"
#import "TagFile.h"
#import "TagLibBridge.h"
#import "TagRating.h"

// Forward declarations — implementations live in TagRating.mm.
// Called here while the FileRef is still open to avoid a second file open.
int TagRatingReadFromFile(TagLib::File *f);
void TagRatingWriteToFile(TagLib::File *f, int stars);

@implementation TagFile

using namespace std;
using namespace TagLib;

- (instancetype)initWithPath:(nonnull NSString *)path {
    self = [super init];

    _path = path;
    _dictionary = [[NSMutableDictionary alloc] init];

    return self;
}

- (bool)load {
    FileRef fileRef(_path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    auto audioProperties = fileRef.audioProperties();

    if (audioProperties != nullptr) {
        _audioProperties = [[TagAudioPropertiesC alloc] init];
        _audioProperties.sampleRate = (double)audioProperties->sampleRate();
        _audioProperties.duration = (double)audioProperties->lengthInMilliseconds() / 1000;
        _audioProperties.bitRate = audioProperties->bitrate();
        _audioProperties.channelCount = audioProperties->channels();
    }

    Tag *tag = fileRef.tag();

    if (!tag) {
        return false;
    }

    PropertyMap properties = tag->properties();

    for (const auto &property : properties) {
        const char *ckey = property.first.toCString(true);
        String cval = property.second.toString();

        NSString *key = @(ckey);
        NSString *object = @(cval.toCString(true)) ?: @"";

        if (key != nil && object != nil) {
            [_dictionary setValue:object forKey:key];
        }
    }

    // Matroska keeps its title in the Segment's Info/Title element rather than as a SimpleTag, so
    // it never appears in the PropertyMap above -- but Tag::title() reads it. That element is where
    // real .mkv files carry their title (it is what `ffmpeg -metadata title=` writes), so without
    // this a Matroska row shows no title at all while every other tag reads fine.
    //
    // Fills a gap only: a format whose PropertyMap already carried TITLE keeps that value, so this
    // cannot change what any existing format reports. Same reasoning as the rating injection below
    // -- done here rather than in Swift so it costs no second FileRef open.
    if ([_dictionary objectForKey:@"TITLE"] == nil) {
        String title = tag->title();

        if (!title.isEmpty()) {
            [_dictionary setValue:@(title.toCString(true)) forKey:@"TITLE"];
        }
    }

    // Inject rating via dedicated dispatch; avoids a second FileRef open after load returns.
    int ratingStars = TagRatingReadFromFile(fileRef.file());
    if (ratingStars >= 1) {
        [_dictionary setValue:[NSString stringWithFormat:@"%d", ratingStars] forKey:@"RATING"];
    }

    return true;
}

- (bool)save {
    // false = skip audio properties parsing (not needed for tag write)
    FileRef fileRef(_path.UTF8String, false);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << _path.UTF8String << endl;
        return false;
    }

    // Extract rating before building the PropertyMap — RATING is routed through
    // format-specific frames (POPM/RATING field/rate atom) via TagRatingWriteToFile,
    // not through the generic PropertyMap which would produce a TXXX:RATING frame.
    // Default to 0 so an absent key clears any existing rating frame (rating removed).
    int ratingStars = 0;
    NSString *ratingValue = [_dictionary objectForKey:@"RATING"];
    if (ratingValue != nil) {
        int v = [ratingValue intValue];
        if (v >= TagRatingMinStars && v <= TagRatingMaxStars)
            ratingStars = v;
    }

    // Capture existing artwork before stripping so it can be preserved across the
    // strip-rewrite cycle. strip() clears ALL tags including embedded pictures, but
    // this method only manages text properties — callers use TagPicture to change
    // or clear artwork explicitly when that is their intent.
    auto existingPictures = fileRef.complexProperties(String("PICTURE"));

    // Cleared before writing, so anything absent from the new dictionary is removed.
    TagUtil::clearTags(fileRef);

    File *f = fileRef.file();

    PropertyMap properties = PropertyMap();

    for (NSString *key in [_dictionary allKeys]) {
        if ([key isEqualToString:@"RATING"])
            continue; // routed via TagRatingWriteToFile below
        NSString *value = [_dictionary objectForKey:key];
        String tagKey = String(key.UTF8String, String::UTF8);
        StringList tagValue = StringList(String(value.UTF8String, String::UTF8));
        properties.insert(tagKey, tagValue);
    }

    properties.removeEmpty();
    fileRef.setProperties(properties);

    if (ratingStars >= 0)
        TagRatingWriteToFile(f, ratingStars);

    // Restore artwork that was present before the strip. This method is responsible
    // only for text tags; callers that explicitly write or clear artwork (via TagPicture)
    // do so after this method returns, overwriting whatever we restore here.
    if (!existingPictures.isEmpty()) {
        fileRef.setComplexProperties(String("PICTURE"), existingPictures);
    }

    return fileRef.save();
}

@end
