// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagUtil_H
#define TagUtil_H

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/mpegfile.h>
#import <taglib/rifffile.h>
#import <taglib/wavfile.h>

#import <taglib/id3v2tag.h>
#import <taglib/privateframe.h>
#import <taglib/tpropertymap.h>

using namespace TagLib;
using namespace std;

namespace TagUtil {
static NSMutableDictionary *convertToDictionary(ID3v2::FrameList frameList) {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    if (frameList.isEmpty()) {
        return dict;
    }

    for (auto it = frameList.begin(); it != frameList.end(); it++) {
        ByteVector frameID = (*it)->frameID();

        if (frameID == "POPM") continue;  // structured frame, not a text tag

        String value = (*it)->toString();

        // custom frame handling

        if (frameID == "TXXX") {
            auto *txxxFrame = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(*it);

            if (!txxxFrame) {
                continue;
            }

            // in taglib fashion, we'll call the the description the ID
            frameID = txxxFrame->description().data(String::UTF8);

            // the fieldList() has all text items, so the description() is first and the actual value is last
            value = txxxFrame->fieldList().back();

        } else if (frameID == "PRIV") {
            auto *privFrame = dynamic_cast<ID3v2::PrivateFrame *>(*it);

            if (!privFrame) {
                continue;
            }

            value = privFrame->data();
        }

        // cout << frameID << " = " << value << endl;

        const char *bytes = frameID.data();
        const unsigned int length = frameID.size();

        NSString *nsKey = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];

        NSString *nsValue = [[NSString alloc] initWithCString:value.toCString(true) encoding:NSUTF8StringEncoding];

        [dict setValue:nsValue ?: @"" forKey:nsKey];
    }

    return dict;
}

static PropertyMap convertToPropertyMap(NSMutableDictionary *dict) {
    PropertyMap properties = PropertyMap();

    if (dict.count == 0) {
        return properties;
    }

    for (NSString *key in [dict allKeys]) {
        NSString *value = [dict objectForKey:key];

        // can be taglib key or 4 char id3 frameID
        String tagKey = String(key.UTF8String, String::UTF8);
        StringList tagValue = StringList(String(value.UTF8String, String::UTF8));

        properties.insert(tagKey, tagValue);
    }

    properties.removeEmpty();

    return properties;
}

static NSMutableDictionary *convertToDictionary(RIFF::Info::FieldListMap infoMap) {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    if (infoMap.isEmpty()) {
        return dict;
    }

    for (const auto &[key, val] : infoMap) {
        const char *bytes = key.data();
        const unsigned int length = key.size();

        NSString *nsKey = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];

        NSString *nsValue = [[NSString alloc] initWithCString:val.toCString(true) encoding:NSUTF8StringEncoding];

        // NSLog(@"%@ = %@", nsKey, nsValue);

        [dict setValue:nsValue ?: @"" forKey:nsKey];
    }

    return dict;
}

/// Parse ID3v2 frames and return them as an NSDictionary.
/// The FileRef is kept alive during conversion to avoid dangling pointers.
static NSMutableDictionary *parseID3ToDictionary(NSString *path) {
    FileRef fileRef(path.UTF8String, false);

    if (fileRef.isNull()) {
        return [[NSMutableDictionary alloc] init];
    }

    File *f = fileRef.file();
    ID3v2::Tag *tag = nullptr;

    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        tag = fp->hasID3v2Tag() ? fp->ID3v2Tag() : nullptr;
    else if (auto *fp = dynamic_cast<RIFF::AIFF::File *>(f))
        tag = fp->hasID3v2Tag() ? fp->tag() : nullptr;
    else if (auto *fp = dynamic_cast<MPEG::File *>(f))
        tag = fp->hasID3v2Tag() ? fp->ID3v2Tag() : nullptr;
    else if (auto *fp = dynamic_cast<FLAC::File *>(f))
        tag = fp->hasID3v2Tag() ? fp->ID3v2Tag() : nullptr;

    if (!tag) {
        cout << "Error: No ID3v2 tag found in " << path.UTF8String << endl;
        return [[NSMutableDictionary alloc] init];
    }

    // Convert while FileRef is still alive to avoid dangling pointers
    return convertToDictionary(tag->frameList());
}
} // namespace TagUtil

#endif // !TagUtil_H
