// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagUtil_H
#define TagUtil_H

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/aifffile.h>
#import <taglib/apetag.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/mp4file.h>
#import <taglib/mp4itemfactory.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/rifffile.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>
#import <taglib/xiphcomment.h>

#import <taglib/commentsframe.h>
#import <taglib/id3v2frame.h>
#import <taglib/id3v2tag.h>
#import <taglib/infotag.h>
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
    // A copy: `frameList` returns the tag's own list, which `removeFrame` mutates.
    const ID3v2::FrameList frames = tag->frameList("PRIV");

    for (auto *frame : frames) {
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

/// The Xiph comment of a FLAC, Vorbis or Opus file; nullptr for any other. `create` applies to FLAC only.
static Ogg::XiphComment *xiphComment(File *file, bool create = false) {
    if (auto *flac = dynamic_cast<FLAC::File *>(file)) return flac->xiphComment(create);
    if (auto *vorbis = dynamic_cast<Ogg::Vorbis::File *>(file)) return vorbis->tag();
    if (auto *opus = dynamic_cast<Ogg::Opus::File *>(file)) return opus->tag();
    return nullptr;
}

/// Whether a property's stored list can be written back as one list. Always, outside ID3v2; in an
/// ID3v2 tag only when one text frame holds it, since `createFrameForProperty` turns a list of
/// comments, lyrics or URLs, each stored as its own frame, into a single TXXX.
static bool storesListInOneFrame(File *file, const String &key, const StringList &values) {
    ID3v2::Tag *tag = nullptr;

    if (auto *mpeg = dynamic_cast<MPEG::File *>(file)) tag = mpeg->ID3v2Tag();
    else if (auto *aiff = dynamic_cast<RIFF::AIFF::File *>(file)) tag = aiff->tag();
    else if (auto *wav = dynamic_cast<RIFF::WAV::File *>(file)) tag = wav->ID3v2Tag();
    else return true;

    if (!tag) return false;

    for (auto *frame : tag->frameList()) {
        const auto *textFrame = dynamic_cast<ID3v2::TextIdentificationFrame *>(frame);
        if (!textFrame) continue;
        const PropertyMap frameProperties = textFrame->asProperties();
        if (frameProperties.contains(key) && frameProperties[key] == values) return true;
    }

    return false;
}

/// A Xiph comment field holding chapters (`CHAPTER000`, `CHAPTER000NAME`, …). They are markers,
/// written by `XiphChapterUtil`; the tag path neither reads, writes nor copies them.
static bool isChapterField(const String &key) {
    return key.upper().startsWith("CHAPTER");
}

/// A Xiph comment's `FMPS_RATING`: the rating writer's own mirror of `RATING`, never a tag.
static bool isRatingMirrorField(const String &key) {
    return key.upper() == "FMPS_RATING";
}

/// Removes `ilst` items in memory: all of them, or with `keepingUnmapped` only those with a property
/// key, leaving `stik`, `rtng`, store IDs, other applications' freeform atoms, `covr` and `rate`.
/// `setProperties` alone misses an iTunes freeform atom whose name is not upper case (`iTunSMPB`):
/// its key reads back upper-cased and names a different atom.
///
/// Never stripped: `strip()` removes `meta` at once and the save reinserts it, two passes over
/// `mdat` (measured 2026-09-08: 33.7 MB written for a 16.8 MB `mdat` on a 100-byte title edit).
static void clearMP4Items(MP4::Tag *tag, bool keepingUnmapped) {
    if (!tag) return;

    const StringList unmapped = keepingUnmapped ? tag->properties().unsupportedData() : StringList();
    StringList keys;
    for (const auto &[key, item] : tag->itemMap()) {
        if (!unmapped.contains(key)) keys.append(key);
    }
    for (const auto &key : std::as_const(keys))
        tag->removeItem(key);
}

/// The MP4 freeform items whose name differs from the one their property key recreates, keyed by
/// that name. TagLib keys an unknown `----:com.apple.iTunes:` item by its upper-cased name, so a tag
/// save would rename it: `iTunSMPB` to `ITUNSMPB`, which AVFoundation then ignores.
static std::map<String, String> mp4FreeformNames(const MP4::Tag *tag) {
    std::map<String, String> names;
    if (!tag) return names;

    const MP4::ItemFactory *factory = MP4::ItemFactory::instance();
    for (const auto &[name, item] : tag->itemMap()) {
        if (!name.startsWith("----:")) continue;

        const String key = factory->propertyKeyForName(name.data(String::UTF8)).upper();
        const String recreated(factory->nameForPropertyKey(key), String::UTF8);
        if (!key.isEmpty() && !recreated.isEmpty() && recreated != name) names[recreated] = name;
    }
    return names;
}

/// Moves each item `setProperties` recreated back to the name `mp4FreeformNames` recorded for it.
static void restoreMP4FreeformNames(MP4::Tag *tag, const std::map<String, String> &names) {
    if (!tag) return;

    for (const auto &[recreated, original] : names) {
        if (!tag->contains(recreated)) continue;

        const MP4::Item item = tag->item(recreated);
        tag->removeItem(recreated);
        tag->setItem(original, item);
    }
}

/// Empties a WAV's ID3 and INFO tags in memory. `strip()` removes their chunks from the file at
/// once, moving everything after them, the audio included when they precede it.
static void clearWaveTags(RIFF::WAV::File *file) {
    // Not over a copy of the list: it owns its frames and would delete them a second time.
    if (ID3v2::Tag *id3 = file->ID3v2Tag()) {
        while (!id3->frameList().isEmpty())
            id3->removeFrame(id3->frameList().front());
    }

    if (RIFF::Info::Tag *info = file->InfoTag()) {
        const RIFF::Info::FieldListMap fields = info->fieldListMap();
        for (const auto &[key, _] : fields)
            info->removeField(key);
    }
}

/// Empties every tag, so the save writes only what the caller sets; `setProperties` alone leaves
/// format-specific storage (iTunes freeform atoms) behind. Every MP4 item goes, cleared in memory
/// as `clearMP4Items` describes. Vorbis, Opus and AIFF have no strip; only their mapped properties
/// clear.
static void clearTags(FileRef &fileRef) {
    File *f = fileRef.file();

    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f)) {
        clearWaveTags(fp);
    } else if (auto *fp = dynamic_cast<MP4::File *>(f)) {
        clearMP4Items(fp->tag(), false);
    } else if (auto *fp = dynamic_cast<MPEG::File *>(f)) {
        fp->strip();
    } else if (auto *fp = dynamic_cast<FLAC::File *>(f)) {
        fp->strip();
    } else {
        fileRef.setProperties(PropertyMap());
    }
}

/// Clears the mapped properties ahead of a tag save. An MP3 or AIFF ID3v2 tag is left alone:
/// `ID3v2::Tag::setProperties` keeps each frame whose properties are unchanged, with its
/// description case and language, and replaces the rest. An MP3's APE tag keeps only its binary
/// items. An MP4 keeps every item without a property key; the rating writer replaces `rate`
/// itself. Any other format is cleared by `clearTags`.
static void clearTagsForSave(FileRef &fileRef) {
    if (auto *fp = dynamic_cast<MPEG::File *>(fileRef.file())) {
        if (APE::Tag *ape = fp->APETag()) ape->setProperties(PropertyMap());
        return;
    }

    if (dynamic_cast<RIFF::AIFF::File *>(fileRef.file())) return;

    if (auto *fp = dynamic_cast<MP4::File *>(fileRef.file())) {
        clearMP4Items(fp->tag(), true);
        return;
    }

    clearTags(fileRef);
}

/// A TXXX, a frame with a property key, or a text frame TagLib keys outside that table. Every
/// other frame is binary, and `setProperties` keeps it as it is.
static bool isTextFrame(const ByteVector &frameID) {
    return frameID == "TXXX" || frameID == "USLT" || frameID == "WXXX" || frameID == "TIPL" ||
           frameID == "TMCL" || !ID3v2::Frame::frameIDToKey(frameID).isEmpty();
}

/// Keyed by frame ID, a TXXX by its description, `PRIV` holding its raw data. `textOnly` keeps
/// only what `isTextFrame` accepts, for a dictionary that goes back through `convertToPropertyMap`,
/// and keys a `COMM` as its PropertyMap key: an undescribed one as `COMM`, a described one as
/// `COMMENT:<DESCRIPTION>`. The first frame for a key wins, as `PropertyMap[key].front()` does.
static NSMutableDictionary *convertToDictionary(ID3v2::FrameList frameList, bool textOnly = false) {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    if (frameList.isEmpty()) {
        return dict;
    }

    for (auto it = frameList.begin(); it != frameList.end(); it++) {
        ByteVector frameID = (*it)->frameID();

        if (frameID == "POPM") continue; // read by TagRating
        if (textOnly && !isTextFrame(frameID)) continue;

        String value = (*it)->toString();

        if (frameID == "TXXX") {
            auto *txxxFrame = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(*it);

            if (!txxxFrame) {
                continue;
            }

            // Keyed by description, as TagLib's PropertyMap does. fieldList() is [description, ..., value].
            frameID = txxxFrame->description().data(String::UTF8);
            value = txxxFrame->fieldList().back();

        } else if (textOnly && frameID == "COMM") {
            auto *commentsFrame = dynamic_cast<ID3v2::CommentsFrame *>(*it);

            if (!commentsFrame) {
                continue;
            }

            const String key = commentsFrame->asProperties().begin()->first;
            frameID = key == "COMMENT" ? ByteVector("COMM") : key.data(String::UTF8);
            value = commentsFrame->text();

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

        if (textOnly && dict[nsKey] != nil && (*it)->frameID() == "COMM") continue;

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
