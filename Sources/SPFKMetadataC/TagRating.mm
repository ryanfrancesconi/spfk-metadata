// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#import <taglib/fileref.h>
#import <taglib/tfile.h>
#import <taglib/tstring.h>
#import <taglib/tstringlist.h>

#import <taglib/mpegfile.h>
#import <taglib/wavfile.h>
#import <taglib/aifffile.h>
#import <taglib/id3v2tag.h>
#import <taglib/popularimeterframe.h>
#import <taglib/textidentificationframe.h>

#import <taglib/flacfile.h>
#import <taglib/vorbisfile.h>
#import <taglib/opusfile.h>
#import <taglib/xiphcomment.h>

#import <taglib/mp4file.h>
#import <taglib/mp4tag.h>

#import <taglib/apefile.h>
#import <taglib/wavpackfile.h>
#import <taglib/apetag.h>

#import <taglib/asffile.h>
#import <taglib/asftag.h>

#import "TagRating.h"

using namespace TagLib;

// MARK: - Scale conversions

// Email tag written into POPM. Many players key the rating off the email;
// "Windows Media Player 9 Series" is the most broadly recognised.
static const char *kPopmEmail = "Windows Media Player 9 Series";

// Normalized 0–100 → 0–5 stars (nearest).
static int starsFromNormalized(int n) {
    if (n <= 0) return 0;
    int s = (int)lround((double)n / 20.0);
    return s < 0 ? 0 : (s > 5 ? 5 : s);
}

// 0–5 stars → POPM rating byte (Windows Media Player mapping).
static int popmByteFromStars(int stars) {
    switch (stars) {
        case 1:  return 1;
        case 2:  return 64;
        case 3:  return 128;
        case 4:  return 196;
        case 5:  return 255;
        default: return 0;
    }
}

// POPM rating byte → 0–5 stars (standard read buckets).
static int starsFromPopmByte(int b) {
    if (b <= 0)   return 0;
    if (b < 32)   return 1;
    if (b < 96)   return 2;
    if (b < 160)  return 3;
    if (b < 224)  return 4;
    return 5;
}

// 0–5 stars → ASF WM/SharedUserRating (0–99).
static unsigned int asfFromStars(int stars) {
    switch (stars) {
        case 1:  return 1;
        case 2:  return 25;
        case 3:  return 50;
        case 4:  return 75;
        case 5:  return 99;
        default: return 0;
    }
}
static int starsFromAsf(int v) {
    if (v <= 0)  return 0;
    if (v < 13)  return 1;
    if (v < 38)  return 2;
    if (v < 63)  return 3;
    if (v < 88)  return 4;
    return 5;
}

static int normalizedFromStars(int stars) { return stars * 20; }

// MARK: - ID3v2 (MP3 / WAV / AIFF)

static int readID3(ID3v2::Tag *tag) {
    if (!tag) return -1;
    ID3v2::FrameList frames = tag->frameList("POPM");
    if (!frames.isEmpty()) {
        if (auto *popm = dynamic_cast<ID3v2::PopularimeterFrame *>(frames.front())) {
            return normalizedFromStars(starsFromPopmByte(popm->rating()));
        }
    }
    // Fallback: TXXX:RATING (0–100 or 0–5).
    ID3v2::FrameList txxx = tag->frameList("TXXX");
    for (auto *f : txxx) {
        if (auto *ud = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(f)) {
            if (ud->description().upper() == String("RATING") && ud->fieldList().size() >= 2) {
                int v = ud->fieldList()[1].toInt();
                return v <= 5 ? normalizedFromStars(v) : v;
            }
        }
    }
    return -1;
}

static void writeID3(ID3v2::Tag *tag, int normalized) {
    if (!tag) return;
    int stars = starsFromNormalized(normalized);

    // POPM
    tag->removeFrames("POPM");
    if (normalized > 0) {
        auto *popm = new ID3v2::PopularimeterFrame();
        popm->setEmail(String(kPopmEmail, String::Latin1));
        popm->setRating(popmByteFromStars(stars));
        tag->addFrame(popm);
    }

    // TXXX:RATING mirror (remove any existing first)
    {
        ID3v2::FrameList txxx = tag->frameList("TXXX");
        ID3v2::FrameList toRemove;
        for (auto *f : txxx) {
            if (auto *ud = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(f)) {
                if (ud->description().upper() == String("RATING")) toRemove.append(f);
            }
        }
        for (auto *f : toRemove) tag->removeFrame(f);
    }
    if (normalized > 0) {
        auto *ud = new ID3v2::UserTextIdentificationFrame(String::UTF8);
        ud->setDescription(String("RATING"));
        ud->setText(String::number(normalized));
        tag->addFrame(ud);
    }
}

// MARK: - Xiph (FLAC / OGG / Opus)

static int readXiph(Ogg::XiphComment *xiph) {
    if (!xiph) return -1;
    const Ogg::FieldListMap &m = xiph->fieldListMap();
    if (m.contains("FMPS_RATING") && !m["FMPS_RATING"].isEmpty()) {
        double v = atof(m["FMPS_RATING"].front().toCString(true));   // 0.0–1.0
        return (int)lround(v * 100.0);
    }
    if (m.contains("RATING") && !m["RATING"].isEmpty()) {
        int v = m["RATING"].front().toInt();
        return v <= 5 ? normalizedFromStars(v) : v;
    }
    return -1;
}

static void writeXiph(Ogg::XiphComment *xiph, int normalized) {
    if (!xiph) return;
    if (normalized > 0) {
        xiph->addField("RATING", String::number(normalized), true);   // replace
        char buf[16];
        snprintf(buf, sizeof(buf), "%.3f", (double)normalized / 100.0);
        xiph->addField("FMPS_RATING", String(buf, String::Latin1), true);
    } else {
        xiph->removeFields("RATING");
        xiph->removeFields("FMPS_RATING");
    }
}

// MARK: - MP4

static const char *kMP4RatingKey = "----:com.apple.iTunes:RATING";

static int readMP4(MP4::Tag *tag) {
    if (!tag) return -1;
    const MP4::ItemMap &items = tag->itemMap();
    if (items.contains(kMP4RatingKey)) {
        StringList sl = items[kMP4RatingKey].toStringList();
        if (!sl.isEmpty()) {
            int v = sl.front().toInt();
            return v <= 5 ? normalizedFromStars(v) : v;
        }
    }
    return -1;
}

static void writeMP4(MP4::Tag *tag, int normalized) {
    if (!tag) return;
    if (normalized > 0) {
        tag->setItem(kMP4RatingKey, MP4::Item(StringList(String::number(normalized))));
    } else {
        tag->removeItem(kMP4RatingKey);
    }
}

// MARK: - APE / WavPack

static int readAPE(APE::Tag *tag) {
    if (!tag) return -1;
    const APE::ItemListMap &m = tag->itemListMap();
    if (m.contains("RATING")) {
        int v = m["RATING"].toString().toInt();
        return v <= 5 ? normalizedFromStars(v) : v;
    }
    return -1;
}

static void writeAPE(APE::Tag *tag, int normalized) {
    if (!tag) return;
    if (normalized > 0) {
        tag->addValue("RATING", String::number(normalized), true);
    } else {
        tag->removeItem("RATING");
    }
}

// MARK: - ASF (WMA)

static int readASF(ASF::Tag *tag) {
    if (!tag) return -1;
    if (tag->contains("WM/SharedUserRating")) {
        ASF::AttributeList l = tag->attribute("WM/SharedUserRating");
        if (!l.isEmpty()) return normalizedFromStars(starsFromAsf((int)l.front().toUInt()));
    }
    return -1;
}

static void writeASF(ASF::Tag *tag, int normalized) {
    if (!tag) return;
    if (normalized > 0) {
        tag->setAttribute("WM/SharedUserRating", ASF::Attribute(asfFromStars(starsFromNormalized(normalized))));
    } else {
        tag->removeItem("WM/SharedUserRating");
    }
}

// MARK: - Public

@implementation TagRating

+ (int)readNormalizedRating:(nonnull NSString *)path {
    FileRef ref(path.UTF8String, false);
    if (ref.isNull()) return -1;
    File *f = ref.file();

    if (auto *mp3 = dynamic_cast<MPEG::File *>(f))            return readID3(mp3->ID3v2Tag(false));
    if (auto *wav = dynamic_cast<RIFF::WAV::File *>(f))       return readID3(wav->ID3v2Tag());
    if (auto *aiff = dynamic_cast<RIFF::AIFF::File *>(f))     return readID3(aiff->tag());
    if (auto *flac = dynamic_cast<FLAC::File *>(f))           return readXiph(flac->xiphComment(false));
    if (auto *vorbis = dynamic_cast<Ogg::Vorbis::File *>(f))  return readXiph(vorbis->tag());
    if (auto *opus = dynamic_cast<Ogg::Opus::File *>(f))      return readXiph(opus->tag());
    if (auto *mp4 = dynamic_cast<MP4::File *>(f))             return readMP4(mp4->tag());
    if (auto *ape = dynamic_cast<APE::File *>(f))             return readAPE(ape->APETag(false));
    if (auto *wv = dynamic_cast<WavPack::File *>(f))          return readAPE(wv->APETag(false));
    if (auto *asf = dynamic_cast<ASF::File *>(f))             return readASF(asf->tag());
    return -1;
}

+ (bool)writeNormalizedRating:(int)rating path:(nonnull NSString *)path {
    if (rating < 0) rating = 0;
    if (rating > 100) rating = 100;

    FileRef ref(path.UTF8String, false);
    if (ref.isNull()) return false;
    File *f = ref.file();

    if (auto *mp3 = dynamic_cast<MPEG::File *>(f))            { writeID3(mp3->ID3v2Tag(true), rating); }
    else if (auto *wav = dynamic_cast<RIFF::WAV::File *>(f))  { writeID3(wav->ID3v2Tag(), rating); }
    else if (auto *aiff = dynamic_cast<RIFF::AIFF::File *>(f)){ writeID3(aiff->tag(), rating); }
    else if (auto *flac = dynamic_cast<FLAC::File *>(f))      { writeXiph(flac->xiphComment(true), rating); }
    else if (auto *vorbis = dynamic_cast<Ogg::Vorbis::File *>(f)) { writeXiph(vorbis->tag(), rating); }
    else if (auto *opus = dynamic_cast<Ogg::Opus::File *>(f)) { writeXiph(opus->tag(), rating); }
    else if (auto *mp4 = dynamic_cast<MP4::File *>(f))        { writeMP4(mp4->tag(), rating); }
    else if (auto *ape = dynamic_cast<APE::File *>(f))        { writeAPE(ape->APETag(true), rating); }
    else if (auto *wv = dynamic_cast<WavPack::File *>(f))     { writeAPE(wv->APETag(true), rating); }
    else if (auto *asf = dynamic_cast<ASF::File *>(f))        { writeASF(asf->tag(), rating); }
    else { return false; }

    return ref.save();
}

@end
