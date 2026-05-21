// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>
#import <string>

#import <taglib/apetag.h>
#import <taglib/asfattribute.h>
#import <taglib/asftag.h>
#import <taglib/mp4item.h>
#import <taglib/mp4tag.h>
#import <taglib/popularimeterframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/id3v2tag.h>
#import <taglib/xiphcomment.h>

#import "TagFileType.h"
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

// ASF WM/SharedUserRating buckets → stars
// Values: 0=no rating, 1=1★, 25=2★, 50=3★, 75=4★, 99=5★
// Read buckets: ≤0→0, 1-12→1, 13-37→2, 38-62→3, 63-87→4, 88-99→5
static int starsFromAsf(int v) {
    if (v <= 0)  return 0;
    if (v <= 12) return 1;
    if (v <= 37) return 2;
    if (v <= 62) return 3;
    if (v <= 87) return 4;
    return 5;
}

static int asfFromStars(int stars) {
    switch (stars) {
        case 1: return 1;
        case 2: return 25;
        case 3: return 50;
        case 4: return 75;
        case 5: return 99;
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

@implementation TagRatingUtil

// MARK: - ID3v2 / POPM

+ (int)readID3v2Rating:(TagLib::ID3v2::Tag *)id3Tag {
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
    for (const auto *f : id3Tag->frameList("TXXX")) {
        const auto *txxx = dynamic_cast<const ID3v2::UserTextIdentificationFrame *>(f);
        if (!txxx) continue;
        if (txxx->description().upper() == "RATING") {
            int v = txxx->fieldList().toString().toInt();
            // Heuristic: ≤5 means star count (some taggers write 0-5), else 0-100 normalized
            if (v <= 5) return normalizedFromStars(v);
            if (v <= 100) return v;
        }
    }

    return -1;
}

+ (void)writeID3v2Rating:(TagLib::ID3v2::Tag *)id3Tag normalized:(int)normalized {
    if (!id3Tag) return;

    id3Tag->removeFrames("POPM");

    if (normalized <= 0) return;

    int popmByte = popmByteFromStars(starsFromNormalized(normalized));

    auto *frame = new ID3v2::PopularimeterFrame();
    frame->setEmail(String(kWMPEmail, String::Latin1));
    frame->setRating(popmByte);
    frame->setCounter(0);
    id3Tag->addFrame(frame);
}

// MARK: - Xiph / Vorbis Comment

+ (int)readXiphRating:(TagLib::Ogg::XiphComment *)xiph {
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

+ (void)writeXiphRating:(TagLib::Ogg::XiphComment *)xiph normalized:(int)normalized {
    if (!xiph) return;

    xiph->removeFields("RATING");
    xiph->removeFields("FMPS_RATING");

    if (normalized <= 0) return;

    xiph->addField("RATING", String(to_string(normalized), String::UTF8));

    std::string fmpsStr = fmpsRatingString(normalized);
    xiph->addField("FMPS_RATING", String(fmpsStr, String::Latin1));
}

// MARK: - MP4

+ (int)readMP4Rating:(TagLib::MP4::Tag *)mp4Tag {
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

+ (void)writeMP4Rating:(TagLib::MP4::Tag *)mp4Tag normalized:(int)normalized {
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

// MARK: - APE

+ (int)readAPERating:(TagLib::APE::Tag *)apeTag {
    if (!apeTag) return -1;

    const APE::ItemListMap &items = apeTag->itemListMap();
    auto it = items.find("RATING");
    if (it != items.end()) {
        int v = it->second.toString().toInt();
        if (v >= 0 && v <= 100) return v;
    }

    return -1;
}

+ (void)writeAPERating:(TagLib::APE::Tag *)apeTag normalized:(int)normalized {
    if (!apeTag) return;

    apeTag->removeItem("RATING");

    if (normalized > 0) {
        apeTag->addValue("RATING", String(to_string(normalized), String::Latin1));
    }
}

// MARK: - ASF (WMA)

+ (int)readASFRating:(TagLib::ASF::Tag *)asfTag {
    if (!asfTag) return -1;

    const ASF::AttributeListMap &attrMap = asfTag->attributeListMap();
    auto it = attrMap.find("WM/SharedUserRating");
    if (it != attrMap.end() && !it->second.isEmpty()) {
        int v = (int)it->second.front().toUInt();
        return normalizedFromStars(starsFromAsf(v));
    }

    return -1;
}

+ (void)writeASFRating:(TagLib::ASF::Tag *)asfTag normalized:(int)normalized {
    if (!asfTag) return;

    asfTag->removeItem("WM/SharedUserRating");

    if (normalized > 0) {
        int asfValue = asfFromStars(starsFromNormalized(normalized));
        asfTag->setAttribute("WM/SharedUserRating", ASF::Attribute((unsigned int)asfValue));
    }
}

// MARK: - Public dispatch

+ (int)readFromTag:(nonnull void *)opaqueTag fileType:(TagFileTypeDef)type {
    if (!opaqueTag) return -1;

    if ([type isEqualToString:kTagFileTypeMp3] ||
        [type isEqualToString:kTagFileTypeAiff] ||
        [type isEqualToString:kTagFileTypeWave]) {
        return [self readID3v2Rating:static_cast<TagLib::ID3v2::Tag *>(opaqueTag)];
    }

    if ([type isEqualToString:kTagFileTypeFlac] ||
        [type isEqualToString:kTagFileTypeVorbis] ||
        [type isEqualToString:kTagFileTypeOpus]) {
        return [self readXiphRating:static_cast<TagLib::Ogg::XiphComment *>(opaqueTag)];
    }

    if ([type isEqualToString:kTagFileTypeM4a] ||
        [type isEqualToString:kTagFileTypeMp4] ||
        [type isEqualToString:kTagFileTypeAac]) {
        return [self readMP4Rating:static_cast<TagLib::MP4::Tag *>(opaqueTag)];
    }

    return -1;
}

+ (void)writeToTag:(nonnull void *)opaqueTag fileType:(TagFileTypeDef)type normalized:(int)normalized {
    if (!opaqueTag) return;

    if ([type isEqualToString:kTagFileTypeMp3] ||
        [type isEqualToString:kTagFileTypeAiff] ||
        [type isEqualToString:kTagFileTypeWave]) {
        [self writeID3v2Rating:static_cast<TagLib::ID3v2::Tag *>(opaqueTag) normalized:normalized];
        return;
    }

    if ([type isEqualToString:kTagFileTypeFlac] ||
        [type isEqualToString:kTagFileTypeVorbis] ||
        [type isEqualToString:kTagFileTypeOpus]) {
        [self writeXiphRating:static_cast<TagLib::Ogg::XiphComment *>(opaqueTag) normalized:normalized];
        return;
    }

    if ([type isEqualToString:kTagFileTypeM4a] ||
        [type isEqualToString:kTagFileTypeMp4] ||
        [type isEqualToString:kTagFileTypeAac]) {
        [self writeMP4Rating:static_cast<TagLib::MP4::Tag *>(opaqueTag) normalized:normalized];
        return;
    }
}

@end
