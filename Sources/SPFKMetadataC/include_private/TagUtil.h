// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagUtil_H
#define TagUtil_H

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/rifffile.h>
#import <taglib/wavfile.h>

#import <taglib/id3v2frame.h>
#import <taglib/id3v2tag.h>
#import <taglib/privateframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>

using namespace TagLib;
using namespace std;

namespace TagUtil {
/// The data of each ID3v2 `PRIV` frame owned by `XMP`, which holds the file's XMP packet.
static vector<ByteVector> xmpPrivateFrameData(ID3v2::Tag *tag) {
    vector<ByteVector> packets;
    if (!tag) return packets;

    for (auto *frame : tag->frameList("PRIV")) {
        auto *privateFrame = dynamic_cast<ID3v2::PrivateFrame *>(frame);
        if (privateFrame && privateFrame->owner() == "XMP") {
            packets.push_back(privateFrame->data());
        }
    }

    return packets;
}

/// Replaces the `XMP`-owned `PRIV` frames with one holding `packet`, or with none when it is empty.
static void setXMPPrivateFrame(ID3v2::Tag *tag, const ByteVector &packet) {
    for (auto *frame : tag->frameList("PRIV")) {
        auto *privateFrame = dynamic_cast<ID3v2::PrivateFrame *>(frame);
        if (privateFrame && privateFrame->owner() == "XMP") {
            tag->removeFrame(privateFrame);
        }
    }

    if (packet.isEmpty()) return;

    auto *privateFrame = new ID3v2::PrivateFrame();
    privateFrame->setOwner("XMP");
    privateFrame->setData(packet);
    tag->addFrame(privateFrame);
}

/// Empties every tag, so the save writes only what the caller sets; `setProperties` alone leaves
/// format-specific storage (iTunes freeform atoms) behind.
///
/// MP4 is cleared in memory, never stripped: `strip()` removes `meta` at once and the save reinserts
/// it, two passes over `mdat` (measured 2026-09-08: 33.7 MB written for a 16.8 MB `mdat` on a
/// 100-byte title edit). Vorbis, Opus and AIFF have no strip; only their mapped properties clear.
static void clearTags(FileRef &fileRef) {
    File *f = fileRef.file();

    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f)) {
        fp->strip();
    } else if (auto *fp = dynamic_cast<MP4::File *>(f)) {
        if (MP4::Tag *tag = fp->tag()) {
            StringList keys;
            for (const auto &[key, item] : tag->itemMap())
                keys.append(key);
            for (const auto &key : std::as_const(keys))
                tag->removeItem(key);
        }
    } else if (auto *fp = dynamic_cast<MPEG::File *>(f)) {
        fp->strip();
    } else if (auto *fp = dynamic_cast<FLAC::File *>(f)) {
        fp->strip();
    } else {
        fileRef.setProperties(PropertyMap());
    }
}

static NSMutableDictionary *convertToDictionary(ID3v2::FrameList frameList) {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    if (frameList.isEmpty()) {
        return dict;
    }

    for (auto it = frameList.begin(); it != frameList.end(); it++) {
        ByteVector frameID = (*it)->frameID();

        if (frameID == "POPM") continue; // read by TagRating

        String value = (*it)->toString();

        if (frameID == "TXXX") {
            auto *txxxFrame = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(*it);

            if (!txxxFrame) {
                continue;
            }

            // Keyed by description, as TagLib's PropertyMap does. fieldList() is [description, ..., value].
            frameID = txxxFrame->description().data(String::UTF8);
            value = txxxFrame->fieldList().back();

        } else if (frameID == "PRIV") {
            auto *privFrame = dynamic_cast<ID3v2::PrivateFrame *>(*it);

            if (!privFrame) {
                continue;
            }

            value = privFrame->data();
        }

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

        String tagKey = String(key.UTF8String, String::UTF8);

        // setProperties() takes property keys ("TITLE"), not frame IDs ("TIT2"). A TXXX
        // description is longer than four characters and passes through as a TXXX frame.
        if (tagKey.size() == 4) {
            String translated = ID3v2::Frame::frameIDToKey(tagKey.data(String::Latin1));
            if (!translated.isEmpty()) {
                tagKey = translated;
            }
        }

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

        [dict setValue:nsValue ?: @"" forKey:nsKey];
    }

    return dict;
}

/// Empty when the file has no ID3v2 tag.
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

    // The frames belong to fileRef, so convert before it goes out of scope.
    return convertToDictionary(tag->frameList());
}
} // namespace TagUtil

#endif // !TagUtil_H
