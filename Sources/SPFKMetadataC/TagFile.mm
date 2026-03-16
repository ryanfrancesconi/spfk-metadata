// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/fileref.h>
#import <taglib/tpropertymap.h>

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
