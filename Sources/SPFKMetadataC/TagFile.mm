// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/id3v2tag.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/privateframe.h>
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
#import "TagRatingFile.h"

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

    // Matroska keeps its title in Segment Info/Title, outside the PropertyMap, where
    // `ffmpeg -metadata title=` writes it. Fills a gap only; a PropertyMap TITLE wins.
    if ([_dictionary objectForKey:@"TITLE"] == nil) {
        String title = tag->title();

        if (!title.isEmpty()) {
            [_dictionary setValue:@(title.toCString(true)) forKey:@"TITLE"];
        }
    }

    // Outside the PropertyMap; see TagRatingFile.h.
    int ratingStars = TagRatingReadFromFile(fileRef.file());
    if (ratingStars >= 1) {
        [_dictionary setValue:[NSString stringWithFormat:@"%d", ratingStars] forKey:@"RATING"];
    }

    return true;
}

- (bool)save {
    // No audio properties: a tag write doesn't need them.
    FileRef fileRef(_path.UTF8String, false);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << _path.UTF8String << endl;
        return false;
    }

    // Kept out of the PropertyMap, where it would become a TXXX:RATING frame.
    int ratingStars = TagRatingStarsInDictionary(_dictionary);

    // clearTags() strips artwork too, and this method writes text only.
    auto existingPictures = fileRef.complexProperties(String("PICTURE"));

    File *f = fileRef.file();
    auto *mpegFile = dynamic_cast<MPEG::File *>(f);

    // The XMP packet has no PropertyMap key, so clearing the tag would delete it.
    vector<ByteVector> xmpPackets;
    if (mpegFile && mpegFile->hasID3v2Tag()) {
        for (auto *frame : mpegFile->ID3v2Tag()->frameList("PRIV")) {
            auto *privateFrame = dynamic_cast<ID3v2::PrivateFrame *>(frame);
            if (privateFrame && privateFrame->owner() == "XMP") {
                xmpPackets.push_back(privateFrame->data());
            }
        }
    }

    // Cleared before writing, so anything absent from the new dictionary is removed.
    TagUtil::clearTags(fileRef);

    PropertyMap properties = PropertyMap();

    for (NSString *key in [_dictionary allKeys]) {
        if ([key isEqualToString:@"RATING"])
            continue;
        NSString *value = [_dictionary objectForKey:key];
        String tagKey = String(key.UTF8String, String::UTF8);
        StringList tagValue = StringList(String(value.UTF8String, String::UTF8));
        properties.insert(tagKey, tagValue);
    }

    properties.removeEmpty();
    fileRef.setProperties(properties);

    if (!TagRatingWriteToFile(f, ratingStars))
        return false;

    for (const auto &packet : xmpPackets) {
        auto *privateFrame = new ID3v2::PrivateFrame();
        privateFrame->setOwner("XMP");
        privateFrame->setData(packet);
        mpegFile->ID3v2Tag(true)->addFrame(privateFrame);
    }

    // A caller changing artwork does so through TagPicture after this returns.
    if (!existingPictures.isEmpty()) {
        fileRef.setComplexProperties(String("PICTURE"), existingPictures);
    }

    return fileRef.save();
}

@end
