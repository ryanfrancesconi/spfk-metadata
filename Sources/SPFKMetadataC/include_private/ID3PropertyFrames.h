// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef ID3PropertyFrames_H
#define ID3PropertyFrames_H

#import <taglib/aifffile.h>
#import <taglib/commentsframe.h>
#import <taglib/id3v2tag.h>
#import <taglib/mpegfile.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>
#import <taglib/uniquefileidentifierframe.h>
#import <taglib/unsynchronizedlyricsframe.h>
#import <taglib/urllinkframe.h>
#import <taglib/wavfile.h>

/// How an ID3v2 tag's frames map onto PropertyMap lists, for a save that writes through
/// `setProperties`.
namespace ID3PropertyFrames {
using namespace TagLib;

/// The ID3v2 tag of an MP3, AIFF or WAV file; nullptr for any other format or when there is none.
static ID3v2::Tag *tag(File *file) {
    if (auto *mpeg = dynamic_cast<MPEG::File *>(file)) return mpeg->ID3v2Tag();
    if (auto *aiff = dynamic_cast<RIFF::AIFF::File *>(file)) return aiff->tag();
    if (auto *wav = dynamic_cast<RIFF::WAV::File *>(file)) return wav->ID3v2Tag();
    return nullptr;
}

/// A frame's properties; empty for a frame with none (`APIC`, `PRIV`, `CHAP`, …).
static PropertyMap properties(const ID3v2::Frame *frame) {
    if (auto *f = dynamic_cast<const ID3v2::TextIdentificationFrame *>(frame)) return f->asProperties();
    if (auto *f = dynamic_cast<const ID3v2::CommentsFrame *>(frame)) return f->asProperties();
    if (auto *f = dynamic_cast<const ID3v2::UnsynchronizedLyricsFrame *>(frame)) return f->asProperties();
    if (auto *f = dynamic_cast<const ID3v2::UrlLinkFrame *>(frame)) return f->asProperties();
    if (auto *f = dynamic_cast<const ID3v2::UniqueFileIdentifierFrame *>(frame)) return f->asProperties();
    return PropertyMap();
}

/// The frames whose properties include `key`.
static ID3v2::FrameList framesHolding(ID3v2::Tag *tag, const String &key) {
    ID3v2::FrameList frames;

    for (auto *frame : tag->frameList()) {
        if (properties(frame).contains(key)) frames.append(frame);
    }

    return frames;
}

/// Whether a property's stored list can be written back as one list. Always, outside ID3v2; in an
/// ID3v2 tag only when one frame holds it, since `createFrameForProperty` turns a list of
/// comments, lyrics or URLs, each stored as its own frame, into a single TXXX.
static bool storesListInOneFrame(File *file, const String &key, const StringList &values) {
    if (!dynamic_cast<MPEG::File *>(file) && !dynamic_cast<RIFF::AIFF::File *>(file) && !dynamic_cast<RIFF::WAV::File *>(file))
        return true;

    ID3v2::Tag *id3 = tag(file);
    if (!id3) return false;

    for (auto *frame : framesHolding(id3, key)) {
        if (properties(frame)[key] == values) return true;
    }

    return false;
}
} // namespace ID3PropertyFrames

#endif // !ID3PropertyFrames_H
