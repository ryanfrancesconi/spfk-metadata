// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <string>

#import <taglib/aifffile.h>
#import <taglib/apefile.h>
#import <taglib/apetag.h>
#import <taglib/asffile.h>
#import <taglib/asftag.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/id3v2tag.h>
#import <taglib/mp4file.h>
#import <taglib/mp4item.h>
#import <taglib/matroskafile.h>
#import <taglib/matroskatag.h>
#import <taglib/mp4tag.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/popularimeterframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>
#import <taglib/wavpackfile.h>
#import <taglib/xiphcomment.h>

#import "TagRating.h"
#import "TagRatingScale.h"

using namespace std;
using namespace TagLib;
using namespace TagRatingScale;

// WMP POPM email
static const char *kWMPEmail = "Windows Media Player 9 Series";

// MP4 atom keys
static const char *kMP4RateKey = "rate";
static const char *kMP4FreeformKey = "----:com.apple.iTunes:RATING";

// MARK: - ID3v2 / POPM

static int readID3(ID3v2::Tag *tag) {
    if (!tag)
        return -1;

    // POPM, preferring the WMP frame over any other.
    const ID3v2::FrameList &popmList = tag->frameList("POPM");
    if (!popmList.isEmpty()) {
        const ID3v2::PopularimeterFrame *wmpFrame = nullptr;
        const ID3v2::PopularimeterFrame *anyFrame = nullptr;

        for (const auto *f : popmList) {
            const auto *popm = dynamic_cast<const ID3v2::PopularimeterFrame *>(f);
            if (!popm)
                continue;
            if (!anyFrame)
                anyFrame = popm;
            if (popm->email().toCString(true) == std::string(kWMPEmail)) {
                wmpFrame = popm;
                break;
            }
        }

        const ID3v2::PopularimeterFrame *best = wmpFrame ? wmpFrame : anyFrame;
        if (best)
            return starsFromPopmByte(best->rating());
    }

    // TXXX:RATING is read, never written: older versions and other tools stored the value there.
    // fieldList() is [description, value, ...].
    for (const auto *f : tag->frameList("TXXX")) {
        const auto *txxx = dynamic_cast<const ID3v2::UserTextIdentificationFrame *>(f);
        if (!txxx)
            continue;
        if (txxx->description().upper() == "RATING") {
            StringList fl = txxx->fieldList();
            int v = (fl.size() >= 2) ? fl[1].toInt() : fl.front().toInt();
            if (int stars = starsFromStoredValue(v); stars > 0)
                return stars;
        }
    }

    return -1;
}

static void writeID3(ID3v2::Tag *tag, int stars) {
    if (!tag)
        return;

    tag->removeFrames("POPM");

    // Collected first: removing invalidates the iteration.
    {
        ID3v2::FrameList toRemove;
        for (auto *f : tag->frameList("TXXX")) {
            auto *ud = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(f);
            if (ud && ud->description().upper() == "RATING")
                toRemove.append(f);
        }
        for (auto *f : toRemove)
            tag->removeFrame(f);
    }

    if (stars <= 0)
        return;

    auto *frame = new ID3v2::PopularimeterFrame();
    frame->setEmail(String(kWMPEmail, String::Latin1)); // ID3v2 POPM email field is ISO-8859-1 (Latin1) per spec
    frame->setRating(popmByteFromStars(stars));
    frame->setCounter(0);
    tag->addFrame(frame);
}

// MARK: - Xiph / Vorbis Comment

static int readXiph(Ogg::XiphComment *xiph) {
    if (!xiph)
        return -1;

    const Ogg::FieldListMap &fields = xiph->fieldListMap();

    auto ratingIt = fields.find("RATING");
    if (ratingIt != fields.end() && !ratingIt->second.isEmpty()) {
        if (int stars = starsFromStoredValue(ratingIt->second.front().toInt()); stars > 0)
            return stars;
    }

    auto fmpsIt = fields.find("FMPS_RATING");
    if (fmpsIt != fields.end() && !fmpsIt->second.isEmpty()) {
        std::string fmpsStr = fmpsIt->second.front().to8Bit(true);
        int normalized = parseFmpsRating(fmpsStr);
        if (normalized > 0)
            return starsFromNormalized(normalized);
    }

    return -1;
}

static void writeXiph(Ogg::XiphComment *xiph, int stars) {
    if (!xiph)
        return;

    xiph->removeFields("RATING");
    xiph->removeFields("FMPS_RATING");

    if (stars <= 0)
        return;

    int normalized = normalizedFromStars(stars);
    xiph->addField("RATING", String(to_string(normalized), String::UTF8));
    xiph->addField("FMPS_RATING", String(fmpsRatingString(normalized), String::UTF8));
}

// MARK: - MP4

static int readMP4(MP4::Tag *tag) {
    if (!tag)
        return -1;

    if (tag->contains(kMP4RateKey)) {
        MP4::Item item = tag->item(kMP4RateKey);
        if (item.isValid()) {
            if (int stars = starsFromStoredValue(item.toInt()); stars > 0)
                return stars;
        }
    }

    if (tag->contains(kMP4FreeformKey)) {
        MP4::Item item = tag->item(kMP4FreeformKey);
        if (item.isValid()) {
            StringList sl = item.toStringList();
            if (!sl.isEmpty()) {
                if (int stars = starsFromStoredValue(sl.front().toInt()); stars > 0)
                    return stars;
            }
        }
    }

    return -1;
}

static void writeMP4(MP4::Tag *tag, int stars) {
    if (!tag)
        return;

    tag->removeItem(kMP4RateKey);
    tag->removeItem(kMP4FreeformKey);

    if (stars <= 0)
        return;

    int normalized = normalizedFromStars(stars);

    // `rate` for Apple Music, the freeform atom for other taggers.
    tag->setItem(kMP4RateKey, MP4::Item((int)normalized));

    StringList sl;
    sl.append(String(to_string(normalized), String::UTF8));
    tag->setItem(kMP4FreeformKey, MP4::Item(sl));
}

// MARK: - APE / WavPack

static int readAPE(APE::Tag *tag) {
    if (!tag)
        return -1;

    const APE::ItemListMap &m = tag->itemListMap();
    auto it = m.find("RATING");
    if (it != m.end()) {
        if (int stars = starsFromStoredValue(it->second.toString().toInt()); stars > 0)
            return stars;
    }

    return -1;
}

static void writeAPE(APE::Tag *tag, int stars) {
    if (!tag)
        return;

    tag->removeItem("RATING");

    if (stars <= 0)
        return;

    tag->addValue("RATING", String::number(normalizedFromStars(stars)), true);
}

// MARK: - Matroska

// RATING is an ordinary SimpleTag, so it goes through the PropertyMap. Read-modify-write:
// setProperties() replaces the whole set, and TagFile::save calls this after writing the other tags.

static int readMatroska(Matroska::Tag *tag) {
    if (!tag)
        return -1;

    PropertyMap properties = tag->properties();
    auto it = properties.find("RATING");
    if (it == properties.end() || it->second.isEmpty())
        return -1;

    int stars = starsFromStoredValue(it->second.front().toInt());
    return stars > 0 ? stars : -1;
}

static void writeMatroska(Matroska::Tag *tag, int stars) {
    if (!tag)
        return;

    PropertyMap properties = tag->properties();
    properties.erase("RATING");

    // Raw stars: the spec leaves the scale to the application, and 0-5 is what mkvpropedit and
    // ffmpeg pass through unchanged.
    if (stars > 0)
        properties.insert("RATING", StringList(String(to_string(stars), String::UTF8)));

    tag->setProperties(properties);
}

// MARK: - ASF / WMA

static int readASF(ASF::Tag *tag) {
    if (!tag)
        return -1;

    if (tag->contains("WM/SharedUserRating")) {
        ASF::AttributeList l = tag->attribute("WM/SharedUserRating");
        if (!l.isEmpty())
            return starsFromAsf((int)l.front().toUInt());
    }

    return -1;
}

static void writeASF(ASF::Tag *tag, int stars) {
    if (!tag)
        return;

    tag->removeItem("WM/SharedUserRating");

    if (stars <= 0)
        return;

    tag->setAttribute("WM/SharedUserRating", ASF::Attribute(asfFromStars(stars)));
}

// MARK: - File-pointer dispatch

// Non-static so TagFile, WaveFileC and TagLibBridge can call them on a file they already have open.

int TagRatingReadFromFile(TagLib::File *f) {
    if (!f) return -1;
    if (auto *fp = dynamic_cast<MPEG::File *>(f))
        return readID3(fp->ID3v2Tag(false));
    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        return readID3(fp->ID3v2Tag());
    if (auto *fp = dynamic_cast<RIFF::AIFF::File *>(f))
        return readID3(fp->tag());
    if (auto *fp = dynamic_cast<FLAC::File *>(f))
        return readXiph(fp->xiphComment(false));
    if (auto *fp = dynamic_cast<Ogg::Vorbis::File *>(f))
        return readXiph(fp->tag());
    if (auto *fp = dynamic_cast<Ogg::Opus::File *>(f))
        return readXiph(fp->tag());
    if (auto *fp = dynamic_cast<MP4::File *>(f))
        return readMP4(fp->tag());
    if (auto *fp = dynamic_cast<APE::File *>(f))
        return readAPE(fp->APETag(false));
    if (auto *fp = dynamic_cast<WavPack::File *>(f))
        return readAPE(fp->APETag(false));
    if (auto *fp = dynamic_cast<ASF::File *>(f))
        return readASF(fp->tag());
    if (auto *fp = dynamic_cast<Matroska::File *>(f))
        return readMatroska(dynamic_cast<Matroska::Tag *>(fp->tag()));
    return -1;
}

void TagRatingWriteToFile(TagLib::File *f, int stars) {
    if (!f) return;
    if (auto *fp = dynamic_cast<MPEG::File *>(f))
        writeID3(fp->ID3v2Tag(true), stars);
    else if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        writeID3(fp->ID3v2Tag(), stars);
    else if (auto *fp = dynamic_cast<RIFF::AIFF::File *>(f))
        writeID3(fp->tag(), stars);
    else if (auto *fp = dynamic_cast<FLAC::File *>(f))
        writeXiph(fp->xiphComment(true), stars);
    else if (auto *fp = dynamic_cast<Ogg::Vorbis::File *>(f))
        writeXiph(fp->tag(), stars);
    else if (auto *fp = dynamic_cast<Ogg::Opus::File *>(f))
        writeXiph(fp->tag(), stars);
    else if (auto *fp = dynamic_cast<MP4::File *>(f))
        writeMP4(fp->tag(), stars);
    else if (auto *fp = dynamic_cast<APE::File *>(f))
        writeAPE(fp->APETag(true), stars);
    else if (auto *fp = dynamic_cast<WavPack::File *>(f))
        writeAPE(fp->APETag(true), stars);
    else if (auto *fp = dynamic_cast<ASF::File *>(f))
        writeASF(fp->tag(), stars);
    else if (auto *fp = dynamic_cast<Matroska::File *>(f))
        writeMatroska(dynamic_cast<Matroska::Tag *>(fp->tag()), stars);
}

// MARK: - Public path-based interface

@implementation TagRating

+ (int)read:(NSString *)path {
    // No audio properties: a rating doesn't need them.
    FileRef fileRef(path.UTF8String, false);
    if (fileRef.isNull())
        return -1;
    return TagRatingReadFromFile(fileRef.file());
}

+ (BOOL)write:(int)stars toPath:(NSString *)path {
    if (stars < TagRatingMinStars)
        stars = TagRatingMinStars;
    if (stars > TagRatingMaxStars)
        stars = TagRatingMaxStars;

    // No audio properties: a rating doesn't need them.
    FileRef fileRef(path.UTF8String, false);
    if (fileRef.isNull())
        return NO;

    TagRatingWriteToFile(fileRef.file(), stars);
    return fileRef.save();
}

@end
