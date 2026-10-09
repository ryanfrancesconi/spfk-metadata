// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <string>

#import <taglib/apetag.h>
#import <taglib/asftag.h>
#import <taglib/id3v2tag.h>
#import <taglib/matroskatag.h>
#import <taglib/mp4item.h>
#import <taglib/mp4tag.h>
#import <taglib/popularimeterframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>
#import <taglib/xiphcomment.h>

#import "TagRatingStores.h"
#import "TagRatingScale.h"

using namespace std;
using namespace TagLib;
using namespace TagRatingScale;

namespace TagRatingStores {

// WMP POPM email
static const char *kWMPEmail = "Windows Media Player 9 Series";

// MP4 atom keys
static const char *kMP4RateKey = "rate";
static const char *kMP4FreeformKey = "----:com.apple.iTunes:RATING";

// MARK: - ID3v2 / POPM

int readID3(ID3v2::Tag *tag) {
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

/// Writes the app's own POPM only; other players' frames, ratings and play counts are kept.
void writeID3(ID3v2::Tag *tag, int stars) {
    if (!tag)
        return;

    bool anotherPlayerRates = false;

    // Collected first: removing invalidates the iteration.
    {
        ID3v2::FrameList toRemove;
        for (auto *f : tag->frameList("POPM")) {
            auto *popm = dynamic_cast<ID3v2::PopularimeterFrame *>(f);
            if (popm && popm->email().toCString(true) == std::string(kWMPEmail))
                toRemove.append(f);
            else if (popm && popm->rating() > 0)
                anotherPlayerRates = true;
        }
        for (auto *f : toRemove)
            tag->removeFrame(f);
    }

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

    // A cleared rating is stored as 0 while another player's rating remains, which the reader would
    // otherwise show in its place.
    if (stars <= 0 && !anotherPlayerRates)
        return;

    auto *frame = new ID3v2::PopularimeterFrame();
    frame->setEmail(String(kWMPEmail, String::Latin1)); // ID3v2 POPM email field is ISO-8859-1 (Latin1) per spec
    frame->setRating(stars > 0 ? popmByteFromStars(stars) : 0);
    frame->setCounter(0);
    tag->addFrame(frame);
}

// MARK: - Xiph / Vorbis Comment

int readXiph(Ogg::XiphComment *xiph) {
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

void writeXiph(Ogg::XiphComment *xiph, int stars) {
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

int readMP4(MP4::Tag *tag) {
    if (!tag)
        return -1;

    if (tag->contains(kMP4RateKey)) {
        MP4::Item item = tag->item(kMP4RateKey);
        if (item.isValid()) {
            // Stored as an integer or as text; TagLib parses the text form into a string list.
            const StringList text = item.toStringList();
            const int value = text.isEmpty() ? item.toInt() : text.front().toInt();
            if (int stars = starsFromStoredValue(value); stars > 0)
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

void writeMP4(MP4::Tag *tag, int stars) {
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

int readAPE(APE::Tag *tag) {
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

void writeAPE(APE::Tag *tag, int stars) {
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

int readMatroska(Matroska::Tag *tag) {
    if (!tag)
        return -1;

    PropertyMap properties = tag->properties();
    auto it = properties.find("RATING");
    if (it == properties.end() || it->second.isEmpty())
        return -1;

    int stars = starsFromStoredValue(it->second.front().toInt());
    return stars > 0 ? stars : -1;
}

void writeMatroska(Matroska::Tag *tag, int stars) {
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

int readASF(ASF::Tag *tag) {
    if (!tag)
        return -1;

    if (tag->contains("WM/SharedUserRating")) {
        ASF::AttributeList l = tag->attribute("WM/SharedUserRating");
        if (!l.isEmpty())
            return starsFromAsf((int)l.front().toUInt());
    }

    return -1;
}

void writeASF(ASF::Tag *tag, int stars) {
    if (!tag)
        return;

    tag->removeItem("WM/SharedUserRating");

    if (stars <= 0)
        return;

    tag->setAttribute("WM/SharedUserRating", ASF::Attribute(asfFromStars(stars)));
}

} // namespace TagRatingStores
