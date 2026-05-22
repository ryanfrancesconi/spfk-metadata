// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata
// Originally authored by tas231, refactored by Ryan Francesconi

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
#import <taglib/mp4tag.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/popularimeterframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>
#import <taglib/wavpackfile.h>
#import <taglib/xiphcomment.h>

#import "TagRating.h"

using namespace std;
using namespace TagLib;

// WMP POPM email
static const char *kWMPEmail = "Windows Media Player 9 Series";

// MP4 atom keys
static const char *kMP4RateKey = "rate";
static const char *kMP4FreeformKey = "----:com.apple.iTunes:RATING";

// MARK: - Scale helpers

// POPM byte → stars using the standard 5-star range mapping adopted by WMP,
// MediaMonkey, and most DJ software (ranges from the POPM de-facto standard).
static int starsFromPopmByte(int b) {
    if (b <= 0)   return 0;
    if (b <= 54)  return 1;   // 1–54
    if (b <= 117) return 2;   // 55–117
    if (b <= 159) return 3;   // 118–159
    if (b <= 223) return 4;   // 160–223
    return 5;                  // 224–255
}

// Stars → POPM byte (Windows Media Player canonical values).
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

// "Normalized" (0–100) is an internal intermediate scale used only within this file.
// It represents stars × 20 (so 1★=20, 2★=40, 3★=60, 4★=80, 5★=100) and serves
// as a common currency when converting between the POPM byte scale (0–255),
// the Xiph RATING integer field (stored as normalized), and the FMPS_RATING float (0.0–1.0).
// It is NOT part of the public API — callers submit and receive star counts (0–5).
static int starsFromNormalized(int n) { return n / 20; }
static int normalizedFromStars(int stars) { return stars * 20; }

// ASF WM/SharedUserRating scale: 0–99 integer stored as unsigned attribute
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

// Locale-safe FMPS_RATING parsing. Returns normalized 0-100, or -1 on failure.
//
// FMPS_RATING stores a decimal string in the range "0.000"–"1.000" representing 0–100%.
// We avoid atof() because it is locale-dependent: on German/French systems (LC_NUMERIC
// uses ',' as decimal separator), atof("0.800") stops at the period and returns 0.0,
// silently wiping 1–4 star ratings on read. On write, snprintf("%.3f", 0.8) produces
// "0,800" — a comma-delimited value that corrupts the field for any other software
// reading the file. We parse and format with pure integer arithmetic instead.
static int parseFmpsRating(const std::string &s) {
    size_t dot = s.find('.');
    if (dot == std::string::npos) return -1;  // no decimal point → invalid

    // Parse integer part before the dot ("0" or "1")
    int whole = 0;
    for (size_t i = 0; i < dot; i++) {
        if (s[i] < '0' || s[i] > '9') return -1;
        whole = whole * 10 + (s[i] - '0');
    }

    // Parse up to 3 fractional digits after the dot, then pad to 3.
    // "800" → frac=800, "8" → frac=800, "80" → frac=800 (all mean 0.800)
    int frac = 0, digits = 0;
    for (size_t i = dot + 1; i < s.size() && digits < 3; i++, digits++) {
        if (s[i] < '0' || s[i] > '9') return -1;
        frac = frac * 10 + (s[i] - '0');
    }
    while (digits < 3) { frac *= 10; digits++; }  // pad: "8" → 800, "80" → 800

    // Convert to 0-100 scale: whole part contributes 100, frac/10 converts thousandths to hundredths.
    // e.g. whole=0, frac=800 → 0 + 80 = 80;  whole=1, frac=0 → 100 + 0 = 100
    int normalized = whole * 100 + frac / 10;
    if (normalized < 0 || normalized > 100) return -1;
    return normalized;
}

// MARK: - ID3v2 / POPM

static int readID3(ID3v2::Tag *tag) {
    if (!tag) return -1;

    // Primary: POPM frame — the canonical ID3v2 rating frame.
    // Prefer WMP email, fall back to any POPM present.
    const ID3v2::FrameList &popmList = tag->frameList("POPM");
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
        if (best)
            return starsFromPopmByte(best->rating());
    }

    // Fallback: TXXX:RATING — read-only fallback for files tagged by older versions or external tools
    // that wrote a 0–100 normalized integer here without a POPM frame.
    // fieldList() for UserTextIdentificationFrame is [description, value, ...]
    for (const auto *f : tag->frameList("TXXX")) {
        const auto *txxx = dynamic_cast<const ID3v2::UserTextIdentificationFrame *>(f);
        if (!txxx) continue;
        if (txxx->description().upper() == "RATING") {
            StringList fl = txxx->fieldList();
            int v = (fl.size() >= 2) ? fl[1].toInt() : fl.front().toInt();
            // Heuristic: ≤5 is a raw star count; >5 and ≤100 is the old normalized scale → convert
            if (v >= 1 && v <= 5) return v;
            if (v > 5 && v <= 100) return starsFromNormalized(v);
        }
    }

    return -1;
}

static void writeID3(ID3v2::Tag *tag, int stars) {
    if (!tag) return;

    tag->removeFrames("POPM");

    // Remove any existing TXXX:RATING written by older versions (collect first to avoid iterator invalidation)
    {
        ID3v2::FrameList toRemove;
        for (auto *f : tag->frameList("TXXX")) {
            auto *ud = dynamic_cast<ID3v2::UserTextIdentificationFrame *>(f);
            if (ud && ud->description().upper() == "RATING") toRemove.append(f);
        }
        for (auto *f : toRemove) tag->removeFrame(f);
    }

    if (stars <= 0) return;

    auto *frame = new ID3v2::PopularimeterFrame();
    frame->setEmail(String(kWMPEmail, String::Latin1));  // ID3v2 POPM email field is ISO-8859-1 (Latin1) per spec
    frame->setRating(popmByteFromStars(stars));
    frame->setCounter(0);
    tag->addFrame(frame);
}

// MARK: - Xiph / Vorbis Comment

static int readXiph(Ogg::XiphComment *xiph) {
    if (!xiph) return -1;

    const Ogg::FieldListMap &fields = xiph->fieldListMap();

    // Primary: RATING — stored as normalized (stars × 20), but some external tools write raw stars
    auto ratingIt = fields.find("RATING");
    if (ratingIt != fields.end() && !ratingIt->second.isEmpty()) {
        int v = ratingIt->second.front().toInt();
        if (v >= 1 && v <= 5)   return v;                   // raw star count
        if (v > 5 && v <= 100)  return starsFromNormalized(v); // normalized → stars
    }

    // Fallback: FMPS_RATING (0.0–1.0 float, locale-safe parse → normalized 0–100 → stars)
    auto fmpsIt = fields.find("FMPS_RATING");
    if (fmpsIt != fields.end() && !fmpsIt->second.isEmpty()) {
        std::string fmpsStr = fmpsIt->second.front().to8Bit(true);
        int normalized = parseFmpsRating(fmpsStr);
        if (normalized > 0) return starsFromNormalized(normalized);
    }

    return -1;
}

static void writeXiph(Ogg::XiphComment *xiph, int stars) {
    if (!xiph) return;

    xiph->removeFields("RATING");
    xiph->removeFields("FMPS_RATING");

    if (stars <= 0) return;

    int normalized = normalizedFromStars(stars);  // stars → 0-100 for field storage
    xiph->addField("RATING", String(to_string(normalized), String::UTF8));
    xiph->addField("FMPS_RATING", String(fmpsRatingString(normalized), String::UTF8));
}

// MARK: - MP4

static int readMP4(MP4::Tag *tag) {
    if (!tag) return -1;

    // Primary: rate atom — stored as normalized (stars × 20), but some tools write raw stars
    if (tag->contains(kMP4RateKey)) {
        MP4::Item item = tag->item(kMP4RateKey);
        if (item.isValid()) {
            int v = item.toInt();
            if (v >= 1 && v <= 5)   return v;
            if (v > 5 && v <= 100)  return starsFromNormalized(v);
        }
    }

    // Fallback: freeform RATING atom — same encoding as rate atom
    if (tag->contains(kMP4FreeformKey)) {
        MP4::Item item = tag->item(kMP4FreeformKey);
        if (item.isValid()) {
            StringList sl = item.toStringList();
            if (!sl.isEmpty()) {
                int v = sl.front().toInt();
                if (v >= 1 && v <= 5)   return v;
                if (v > 5 && v <= 100)  return starsFromNormalized(v);
            }
        }
    }

    return -1;
}

static void writeMP4(MP4::Tag *tag, int stars) {
    if (!tag) return;

    tag->removeItem(kMP4RateKey);
    tag->removeItem(kMP4FreeformKey);

    if (stars <= 0) return;

    int normalized = normalizedFromStars(stars);  // stars → 0-100 for atom storage

    // Write rate atom (Apple Music)
    tag->setItem(kMP4RateKey, MP4::Item((int)normalized));

    // Write freeform atom (third-party tagger interop)
    StringList sl;
    sl.append(String(to_string(normalized), String::UTF8));
    tag->setItem(kMP4FreeformKey, MP4::Item(sl));
}

// MARK: - APE / WavPack

static int readAPE(APE::Tag *tag) {
    if (!tag) return -1;

    const APE::ItemListMap &m = tag->itemListMap();
    auto it = m.find("RATING");
    if (it != m.end()) {
        int v = it->second.toString().toInt();
        if (v >= 1 && v <= 5)   return v;                   // raw star count
        if (v > 5 && v <= 100)  return starsFromNormalized(v); // normalized → stars
    }

    return -1;
}

static void writeAPE(APE::Tag *tag, int stars) {
    if (!tag) return;

    tag->removeItem("RATING");

    if (stars <= 0) return;

    tag->addValue("RATING", String::number(normalizedFromStars(stars)), true);
}

// MARK: - ASF / WMA

static int readASF(ASF::Tag *tag) {
    if (!tag) return -1;

    if (tag->contains("WM/SharedUserRating")) {
        ASF::AttributeList l = tag->attribute("WM/SharedUserRating");
        if (!l.isEmpty())
            return starsFromAsf((int)l.front().toUInt());  // starsFromAsf already returns 0–5
    }

    return -1;
}

static void writeASF(ASF::Tag *tag, int stars) {
    if (!tag) return;

    tag->removeItem("WM/SharedUserRating");

    if (stars <= 0) return;

    tag->setAttribute("WM/SharedUserRating", ASF::Attribute(asfFromStars(stars)));
}

// MARK: - Public path-based interface

@implementation TagRating

+ (int)read:(NSString *)path {
    // false = skip audio properties parsing (not needed for rating I/O)
    FileRef fileRef(path.UTF8String, false);
    if (fileRef.isNull()) return -1;

    File *f = fileRef.file();

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

    return -1;
}

+ (BOOL)write:(int)stars toPath:(NSString *)path {
    if (stars < 0) stars = 0;
    if (stars > 5) stars = 5;

    // false = skip audio properties parsing (not needed for rating I/O)
    FileRef fileRef(path.UTF8String, false);
    if (fileRef.isNull()) return NO;

    File *f = fileRef.file();

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
    else
        return NO;

    return fileRef.save();
}

@end
