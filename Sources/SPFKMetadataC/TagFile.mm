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
#import "TagFile.h"
#import "TagLibBridge.h"

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

    return true;
}

- (bool)save {
    // false = skip audio properties parsing (not needed for tag write)
    FileRef fileRef(_path.UTF8String, false);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << _path.UTF8String << endl;
        return false;
    }

    // Strip existing tags before writing so that atoms not present in the new
    // dictionary are removed. setProperties alone does not clear format-specific
    // storage like iTunes freeform atoms (e.g. ITUNSMPB in M4A files).
    File *f = fileRef.file();

    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        fp->strip();
    else if (auto *fp = dynamic_cast<MP4::File *>(f))
        fp->strip();
    else if (auto *fp = dynamic_cast<MPEG::File *>(f))
        fp->strip();
    else if (auto *fp = dynamic_cast<FLAC::File *>(f))
        fp->strip();
    else
        fileRef.setProperties(PropertyMap());

    PropertyMap properties = PropertyMap();

    for (NSString *key in [_dictionary allKeys]) {
        NSString *value = [_dictionary objectForKey:key];
        String tagKey = String(key.UTF8String, String::UTF8);
        StringList tagValue = StringList(String(value.UTF8String, String::UTF8));
        properties.insert(tagKey, tagValue);
    }

    properties.removeEmpty();
    fileRef.setProperties(properties);

    return fileRef.save();
}

@end
