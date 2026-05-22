// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <string>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/id3v2tag.h>
#import <taglib/mp4file.h>
#import <taglib/mp4item.h>
#import <taglib/mp4tag.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/popularimeterframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>
#import <taglib/xiphcomment.h>

#import "TagRatingUtil.h"

using namespace std;
using namespace TagLib;

// WMP POPM email
static const char *kWMPEmail = "Windows Media Player 9 Series";

// MP4 atom keys
static const char *kMP4RateKey = "rate";
static const char *kMP4FreeformKey = "----:com.apple.iTunes:RATING";

// MARK: - Conversion helpers

// POPM WMP byte buckets → stars
// Byte: 0=no rating, 1=1★, 64=2★, 128=3★, 196=4★, 255=5★
static int starsFromPopmByte(int b) {
    if (b <= 0)  return 0;
    if (b < 64)  return 1;
    if (b < 128) return 2;
    if (b < 196) return 3;
    if (b < 255) return 4;
    return 5;
}

static int popmByteFromStars(int stars) {
    switch (stars) {
        case 1: return 1;
        case 2: return 64;
        case 3: return 128;
        case 4: return 196;
        case 5: return 255;
        default: return 0;
    }
}

static int starsFromNormalized(int n) { return n / 20; }
static int normalizedFromStars(int stars) { return stars * 20; }

// Locale-safe FMPS_RATING formatting: normalized 0-100 → "d.ddd" string.
// Uses integer arithmetic to avoid LC_NUMERIC locale issues with snprintf/atof.
static std::string fmpsRatingString(int normalized) {
    // normalized 80 → "0.800", 100 → "1.000", 0 → "0.000"
    int whole = normalized / 100;
    int frac3 = (normalized % 100) * 10;   // e.g. 80 → 800
    char buf[16];
    snprintf(buf, sizeof(buf), "%d.%03d", whole, frac3);
    return std::string(buf);
}

// Locale-safe FMPS_RATING parsing. Returns -1 on failure.
static int parseFmpsRating(const std::string &s) {
    size_t dot = s.find('.');
    if (dot == std::string::npos) return -1;

    int whole = 0;
    for (size_t i = 0; i < dot; i++) {
        if (s[i] < '0' || s[i] > '9') return -1;
        whole = whole * 10 + (s[i] - '0');
    }

    int frac = 0, digits = 0;
    for (size_t i = dot + 1; i < s.size() && digits < 3; i++, digits++) {
        if (s[i] < '0' || s[i] > '9') return -1;
        frac = frac * 10 + (s[i] - '0');
    }
    while (digits < 3) { frac *= 10; digits++; }

    // whole=0 or 1, frac=000-999 representing fractional part
    int normalized = whole * 100 + frac / 10;
    if (normalized < 0 || normalized > 100) return -1;
    return normalized;
}

// MARK: - Private interface

@interface TagRatingUtil ()

+ (int)readID3v2:(TagLib::ID3v2::Tag *)id3Tag;
+ (void)writeID3v2:(TagLib::ID3v2::Tag *)id3Tag normalized:(int)normalized;

+ (int)readXiph:(TagLib::Ogg::XiphComment *)xiph;
+ (void)writeXiph:(TagLib::Ogg::XiphComment *)xiph normalized:(int)normalized;

+ (int)readMP4:(TagLib::MP4::Tag *)mp4Tag;
+ (void)writeMP4:(TagLib::MP4::Tag *)mp4Tag normalized:(int)normalized;

@end

@implementation TagRatingUtil

// MARK: - ID3v2 / POPM

+ (int)readID3v2:(TagLib::ID3v2::Tag *)id3Tag {
    if (!id3Tag) return -1;

    // Primary: POPM frame — prefer WMP email, fall back to any POPM
    const ID3v2::FrameList &popmList = id3Tag->frameList("POPM");
    if (!popmList.isEmpty()) {
        const ID3v2::PopularimeterFrame *wmpFrame = nullptr;
        const ID3v2::PopularimeterFrame *anyFrame = nullptr;

        for (const auto *f : popmList) {
            const auto *popm = dynamic_cast<const ID3v2::PopularimeterFrame *>(f);
            if (!popm) continue;
            if (!anyFrame) anyFrame = popm;
            if (popm->email().toCString(true) == std::string(kWMPEmail)) {
                wmpFrame = popm;
                break;
            }
        }

        const ID3v2::PopularimeterFrame *best = wmpFrame ? wmpFrame : anyFrame;
        if (best) {
            int stars = starsFromPopmByte(best->rating());
            return normalizedFromStars(stars);
        }
    }

    // Fallback: TXXX:RATING (written by simpler taggers)
    // fieldList() for UserTextIdentificationFrame is [description, value, ...]
    for (const auto *f : id3Tag->frameList("TXXX")) {
        const auto *txxx = dynamic_cast<const ID3v2::UserTextIdentificationFrame *>(f);
        if (!txxx) continue;
        if (txxx->description().upper() == "RATING") {
            StringList fl = txxx->fieldList();
            int v = (fl.size() >= 2) ? fl[1].toInt() : fl.front().toInt();
            // Heuristic: ≤5 means star count, else 0-100 normalized
            if (v <= 5) return normalizedFromStars(v);
            if (v <= 100) return v;
        }
    }

    return -1;
}

+ (void)writeID3v2:(TagLib::ID3v2::Tag *)id3Tag normalized:(int)normalized {
    if (!id3Tag) return;

    id3Tag->removeFrames("POPM");

    // Remove any existing TXXX:RATING (collect first to avoid iterator invalidation)
    {
        ID3v2::FrameList toRemove;
        for (auto *f : id3Tag->frameList("TXXX")) {
            auto *ud = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(f);
            if (ud && ud->description().upper() == "RATING") toRemove.append(f);
        }
        for (auto *f : toRemove) id3Tag->removeFrame(f);
    }

    if (normalized <= 0) return;

    int popmByte = popmByteFromStars(starsFromNormalized(normalized));

    auto *frame = new ID3v2::PopularimeterFrame();
    frame->setEmail(String(kWMPEmail, String::Latin1));
    frame->setRating(popmByte);
    frame->setCounter(0);
    id3Tag->addFrame(frame);

    // Mirror to TXXX:RATING for interop with simpler taggers
    auto *txxx = new ID3v2::UserTextIdentificationFrame(String::UTF8);
    txxx->setDescription(String("RATING"));
    txxx->setText(String::number(normalized));
    id3Tag->addFrame(txxx);
}

// MARK: - Xiph / Vorbis Comment

+ (int)readXiph:(TagLib::Ogg::XiphComment *)xiph {
    if (!xiph) return -1;

    const Ogg::FieldListMap &fields = xiph->fieldListMap();

    // Primary: RATING (0-100 integer)
    auto ratingIt = fields.find("RATING");
    if (ratingIt != fields.end() && !ratingIt->second.isEmpty()) {
        int v = ratingIt->second.front().toInt();
        if (v >= 0 && v <= 100) return v;
    }

    // Fallback: FMPS_RATING (0.0-1.0 float, locale-safe parse)
    auto fmpsIt = fields.find("FMPS_RATING");
    if (fmpsIt != fields.end() && !fmpsIt->second.isEmpty()) {
        std::string fmpsStr = fmpsIt->second.front().to8Bit(true);
        int v = parseFmpsRating(fmpsStr);
        if (v >= 0) return v;
    }

    return -1;
}

+ (void)writeXiph:(TagLib::Ogg::XiphComment *)xiph normalized:(int)normalized {
    if (!xiph) return;

    xiph->removeFields("RATING");
    xiph->removeFields("FMPS_RATING");

    if (normalized <= 0) return;

    xiph->addField("RATING", String(to_string(normalized), String::UTF8));

    std::string fmpsStr = fmpsRatingString(normalized);
    xiph->addField("FMPS_RATING", String(fmpsStr, String::Latin1));
}

// MARK: - MP4

+ (int)readMP4:(TagLib::MP4::Tag *)mp4Tag {
    if (!mp4Tag) return -1;

    // Primary: rate atom (Apple Music, 0-100 integer)
    if (mp4Tag->contains(kMP4RateKey)) {
        MP4::Item item = mp4Tag->item(kMP4RateKey);
        if (item.isValid()) {
            int v = item.toInt();
            if (v > 0 && v <= 100) return v;
        }
    }

    // Fallback: freeform RATING atom (third-party tagger compatible)
    if (mp4Tag->contains(kMP4FreeformKey)) {
        MP4::Item item = mp4Tag->item(kMP4FreeformKey);
        if (item.isValid()) {
            StringList sl = item.toStringList();
            if (!sl.isEmpty()) {
                int v = sl.front().toInt();
                if (v > 0 && v <= 100) return v;
            }
        }
    }

    return -1;
}

+ (void)writeMP4:(TagLib::MP4::Tag *)mp4Tag normalized:(int)normalized {
    if (!mp4Tag) return;

    mp4Tag->removeItem(kMP4RateKey);
    mp4Tag->removeItem(kMP4FreeformKey);

    if (normalized <= 0) return;

    // Write rate atom (Apple Music)
    mp4Tag->setItem(kMP4RateKey, MP4::Item((int)normalized));

    // Write freeform atom (third-party tagger interop)
    StringList sl;
    sl.append(String(to_string(normalized), String::Latin1));
    mp4Tag->setItem(kMP4FreeformKey, MP4::Item(sl));
}

// MARK: - Public path-based interface

+ (int)readRating:(NSString *)path {
    // false = skip audio properties parsing (not needed for rating I/O)
    FileRef fileRef(path.UTF8String, false);
    if (fileRef.isNull()) return -1;

    File *f = fileRef.file();

    if (auto *fp = dynamic_cast<MPEG::File *>(f))
        return [self readID3v2:fp->ID3v2Tag(false)];
    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        return [self readID3v2:fp->ID3v2Tag()];
    if (auto *fp = dynamic_cast<RIFF::AIFF::File *>(f))
        return [self readID3v2:fp->tag()];
    if (auto *fp = dynamic_cast<FLAC::File *>(f))
        return [self readXiph:fp->xiphComment(false)];
    if (auto *fp = dynamic_cast<Ogg::Vorbis::File *>(f))
        return [self readXiph:fp->tag()];
    if (auto *fp = dynamic_cast<Ogg::Opus::File *>(f))
        return [self readXiph:fp->tag()];
    if (auto *fp = dynamic_cast<MP4::File *>(f))
        return [self readMP4:fp->tag()];

    return -1;
}

+ (BOOL)writeRating:(int)normalized toPath:(NSString *)path {
    if (normalized < 0) normalized = 0;
    if (normalized > 100) normalized = 100;

    // false = skip audio properties parsing (not needed for rating I/O)
    FileRef fileRef(path.UTF8String, false);
    if (fileRef.isNull()) return NO;

    File *f = fileRef.file();

    if (auto *fp = dynamic_cast<MPEG::File *>(f))
        [self writeID3v2:fp->ID3v2Tag(true) normalized:normalized];
    else if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        [self writeID3v2:fp->ID3v2Tag() normalized:normalized];
    else if (auto *fp = dynamic_cast<RIFF::AIFF::File *>(f))
        [self writeID3v2:fp->tag() normalized:normalized];
    else if (auto *fp = dynamic_cast<FLAC::File *>(f)) {
        Ogg::XiphComment *xiph = fp->xiphComment(true);
        if (xiph) [self writeXiph:xiph normalized:normalized];
    }
    else if (auto *fp = dynamic_cast<Ogg::Vorbis::File *>(f))
        [self writeXiph:fp->tag() normalized:normalized];
    else if (auto *fp = dynamic_cast<Ogg::Opus::File *>(f))
        [self writeXiph:fp->tag() normalized:normalized];
    else if (auto *fp = dynamic_cast<MP4::File *>(f))
        [self writeMP4:fp->tag() normalized:normalized];
    else
        return NO;

    return fileRef.save();
}

@end
