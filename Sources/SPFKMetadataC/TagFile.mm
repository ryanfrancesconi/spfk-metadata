// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/id3v1tag.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/rifffile.h>
#import <taglib/tpropertymap.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>

#import "StringUtil.h"
#import "TagAudioPropertiesC.h"
#import "ID3PropertyFrames.h"
#import "TagUtil.h"
#import "TagFile.h"
#import "TagLibBridge.h"
#import "TagRating.h"
#import "TagRatingFile.h"
#import "FileSave.h"

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
    const bool hasXiphComment = TagUtil::xiphComment(fileRef.file()) != nullptr;

    // TagLib maps the `rate` atom to RATING unconverted; the rating read below is on the star scale.
    if (dynamic_cast<MP4::File *>(fileRef.file()))
        properties.erase("RATING");

    for (const auto &property : properties) {
        // Read as markers, by XiphChapterUtil, and as the rating, below.
        if (hasXiphComment && (TagUtil::isChapterField(property.first) || TagUtil::isRatingMirrorField(property.first))) continue;

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

    if (auto *mpegFile = dynamic_cast<MPEG::File *>(fileRef.file()); mpegFile && mpegFile->hasID3v2Tag()) {
        auto packets = TagUtil::xmpPrivateFrameData(mpegFile->ID3v2Tag());
        _xmpPacket = packets.empty() ? nil : [[NSString alloc] initWithBytes:packets.front().data()
                                                                       length:packets.front().size()
                                                                     encoding:NSUTF8StringEncoding];
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

    return [self writeToFileRef:&fileRef] && FileSave::save(fileRef.file());
}

- (bool)writeToFileRef:(void *)fileRef {
    return [self writeToFile:static_cast<FileRef *>(fileRef)->file()];
}

- (bool)writeToFile:(void *)file {
    File *f = static_cast<File *>(file);

    // Kept out of the PropertyMap, where it would become a TXXX:RATING frame.
    int ratingStars = TagRatingStarsInDictionary(_dictionary);

    auto *mpegFile = dynamic_cast<MPEG::File *>(f);
    auto *wavFile = dynamic_cast<RIFF::WAV::File *>(f);

    // A WAV's properties are its ID3v2 tag's; INFO is its writer's mirror.
    Tag *propertyTag = wavFile ? wavFile->ID3v2Tag() : f->tag();

    // Clearing removes artwork in most formats, and this method writes text only. A WAV's ID3v2
    // tag is not cleared, so its pictures are never touched.
    auto existingPictures = wavFile ? List<VariantMap>() : f->complexProperties(String("PICTURE"));

    // Chapter fields are the markers' to write, so they stay as they are on disk.
    Ogg::FieldListMap chapterFields;
    const bool hasXiphComment = TagUtil::xiphComment(f) != nullptr;
    if (hasXiphComment) {
        for (const auto &[key, values] : TagUtil::xiphComment(f)->fieldListMap()) {
            if (TagUtil::isChapterField(key)) chapterFields.insert(key, values);
        }
    }

    auto *mp4File = dynamic_cast<MP4::File *>(f);
    const auto freeformNames = TagUtil::mp4FreeformNames(mp4File ? mp4File->tag() : nullptr);

    // `load` joins a multi-valued property into one string; a value that still equals that join
    // was not edited, so the stored list is written back whole. A list spread over several ID3v2
    // frames (two COMMs) cannot pass through `setProperties`; its frames are detached here and
    // re-added after it. Read before the clear.
    PropertyMap storedLists;
    PropertyMap keptLists;
    ID3v2::FrameList keptFrames;
    ID3v2::Tag *id3 = ID3PropertyFrames::tag(f);

    if (propertyTag) {
        for (const auto &[key, values] : propertyTag->properties()) {
            if (values.size() < 2) continue;

            if (ID3PropertyFrames::storesListInOneFrame(f, key, values)) {
                storedLists.insert(key, values);
                continue;
            }

            NSString *value = [_dictionary objectForKey:@(key.toCString(true))];
            if (!id3 || value == nil || String(value.UTF8String, String::UTF8) != values.toString()) continue;

            keptLists.insert(key, values);
            keptFrames.append(ID3PropertyFrames::framesHolding(id3, key));
        }
    }

    for (auto *frame : keptFrames) id3->removeFrame(frame, false);

    // Cleared before writing, so anything absent from the new dictionary is removed.
    TagUtil::clearTagsForSave(f);

    PropertyMap properties = PropertyMap();

    for (NSString *key in [_dictionary allKeys]) {
        if ([key isEqualToString:@"RATING"])
            continue;
        NSString *value = [_dictionary objectForKey:key];
        String tagKey = String(key.UTF8String, String::UTF8);
        if ((hasXiphComment && TagUtil::isChapterField(tagKey)) || keptLists.contains(tagKey))
            continue;
        const String tagString = String(value.UTF8String, String::UTF8);
        const StringList stored = storedLists.value(tagKey);
        properties.insert(tagKey, !stored.isEmpty() && stored.toString() == tagString ? stored : StringList(tagString));
    }

    properties.removeEmpty();

    if (wavFile)
        wavFile->ID3v2Tag()->setProperties(properties);
    else
        f->setProperties(properties);

    TagUtil::restoreMP4FreeformNames(mp4File ? mp4File->tag() : nullptr, freeformNames);

    for (auto *frame : keptFrames) id3->addFrame(frame);

    // `setProperties` gave an MP3's ID3v1 tag the properties without the kept lists.
    if (mpegFile && mpegFile->ID3v1Tag() && !keptLists.isEmpty()) {
        PropertyMap id3v1Properties = properties;
        mpegFile->ID3v1Tag()->setProperties(id3v1Properties.merge(keptLists));
    }

    // After `setProperties`, which removes every field absent from `properties`.
    for (const auto &[key, values] : chapterFields) {
        for (const auto &value : values) TagUtil::xiphComment(f, true)->addField(key, value, false);
    }

    if (!TagRatingWriteToFile(f, ratingStars))
        return false;

    // The clear keeps the stored packet's `PRIV` frame, so it changes only when asked.
    if (mpegFile && _xmpNeedsSave) {
        ByteVector xmpPacket = _xmpPacket.length > 0 ? ByteVector(_xmpPacket.UTF8String) : ByteVector();
        TagUtil::setXMPPrivateFrame(mpegFile->ID3v2Tag(true), xmpPacket);
    }

    // A caller changing artwork does so through TagPicture after this returns.
    if (!existingPictures.isEmpty()) {
        f->setComplexProperties(String("PICTURE"), existingPictures);
    }

    return true;
}

@end
