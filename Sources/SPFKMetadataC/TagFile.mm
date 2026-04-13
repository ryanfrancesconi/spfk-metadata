// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/rifffile.h>
#import <taglib/tpropertymap.h>
#import <taglib/wavfile.h>

#import "StringUtil.h"
#import "TagAudioPropertiesC.h"
#import "TagFile.h"
#import "TagFileType.h"
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

    if (properties.isEmpty()) {
        return true;
    }

    // Copy TagLib's PropertyMap into our dictionary using the same keys they use.
    // See TagKey for translations.

    for (const auto &property : properties) {
        const char *ckey = property.first.toCString();
        String cval = property.second.toString();

        // cout << ckey << " = " << cval << endl;

        NSString *key = @(ckey);
        NSString *object = @(cval.toCString()) ?: @"";

        if (key != nil && object != nil) {
            [_dictionary setValue:object forKey:key];
        }
    }

    return true;
}

- (bool)save {
    return [TagFile write:_dictionary path:_path];
}

+ (bool)write:(nonnull NSDictionary *)dictionary path:(nonnull NSString *)path {
    FileRef fileRef(path.UTF8String);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << path.UTF8String << endl;
        return false;
    }

    // Strip existing tags before writing so that atoms not present in the new
    // dictionary are removed. setProperties alone does not clear format-specific
    // storage like iTunes freeform atoms (e.g. ITUNSMPB in M4A files).
    NSString *fileType = [TagFileType detectType:path];

    if ([fileType isEqualToString:kTagFileTypeWave]) {
        auto *f = dynamic_cast<RIFF::WAV::File *>(fileRef.file());
        if (f) f->strip();
    } else if ([fileType isEqualToString:kTagFileTypeM4a] || [fileType isEqualToString:kTagFileTypeMp4]) {
        auto *f = dynamic_cast<MP4::File *>(fileRef.file());
        if (f) f->strip();
    } else if ([fileType isEqualToString:kTagFileTypeMp3]) {
        auto *f = dynamic_cast<MPEG::File *>(fileRef.file());
        if (f) f->strip();
    } else if ([fileType isEqualToString:kTagFileTypeFlac]) {
        auto *f = dynamic_cast<FLAC::File *>(fileRef.file());
        if (f) f->strip();
    } else {
        fileRef.setProperties(PropertyMap());
    }

    PropertyMap properties = PropertyMap();

    for (NSString *key in [dictionary allKeys]) {
        NSString *value = [dictionary objectForKey:key];
        String tagKey = String(key.UTF8String);
        StringList tagValue = StringList(value.UTF8String);
        properties.insert(tagKey, tagValue);
    }

    properties.removeEmpty();
    fileRef.setProperties(properties);

    return fileRef.save();
}

@end
