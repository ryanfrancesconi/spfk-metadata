// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <string>
#import <variant>

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
#import "TagRatingFile.h"
#import "TagRatingStores.h"
#import "FileSave.h"

using namespace std;
using namespace TagLib;
using namespace TagRatingStores;

// MARK: - File-pointer dispatch

// A null tag is still its container's alternative: the reader and writer treat it as nothing to do.
using RatingStore = variant<monostate, ID3v2::Tag *, Ogg::XiphComment *, MP4::Tag *, APE::Tag *, ASF::Tag *,
                            Matroska::Tag *>;

template <class... Fs>
struct Overloaded : Fs... {
    using Fs::operator()...;
};

static RatingStore ratingStore(TagLib::File *f, bool create) {
    if (auto *fp = dynamic_cast<MPEG::File *>(f))
        return fp->ID3v2Tag(create);
    if (auto *fp = dynamic_cast<RIFF::WAV::File *>(f))
        return fp->ID3v2Tag();
    if (auto *fp = dynamic_cast<RIFF::AIFF::File *>(f))
        return fp->tag();
    if (auto *fp = dynamic_cast<FLAC::File *>(f))
        return fp->xiphComment(create);
    if (auto *fp = dynamic_cast<Ogg::Vorbis::File *>(f))
        return fp->tag();
    if (auto *fp = dynamic_cast<Ogg::Opus::File *>(f))
        return fp->tag();
    if (auto *fp = dynamic_cast<MP4::File *>(f))
        return fp->tag();
    if (auto *fp = dynamic_cast<APE::File *>(f))
        return fp->APETag(create);
    if (auto *fp = dynamic_cast<WavPack::File *>(f))
        return fp->APETag(create);
    if (auto *fp = dynamic_cast<ASF::File *>(f))
        return fp->tag();
    if (auto *fp = dynamic_cast<Matroska::File *>(f))
        return dynamic_cast<Matroska::Tag *>(fp->tag());
    return monostate();
}

int TagRatingReadFromFile(TagLib::File *f) {
    return visit(Overloaded {
                     [](monostate) { return -1; },
                     [](ID3v2::Tag *tag) { return readID3(tag); },
                     [](Ogg::XiphComment *tag) { return readXiph(tag); },
                     [](MP4::Tag *tag) { return readMP4(tag); },
                     [](APE::Tag *tag) { return readAPE(tag); },
                     [](ASF::Tag *tag) { return readASF(tag); },
                     [](Matroska::Tag *tag) { return readMatroska(tag); },
                 },
                 ratingStore(f, false));
}

bool TagRatingWriteToFile(TagLib::File *f, int stars) {
    return visit(Overloaded {
                     [&](monostate) { return stars <= 0; },
                     [&](ID3v2::Tag *tag) { writeID3(tag, stars); return true; },
                     [&](Ogg::XiphComment *tag) { writeXiph(tag, stars); return true; },
                     [&](MP4::Tag *tag) { writeMP4(tag, stars); return true; },
                     [&](APE::Tag *tag) { writeAPE(tag, stars); return true; },
                     [&](ASF::Tag *tag) { writeASF(tag, stars); return true; },
                     [&](Matroska::Tag *tag) { writeMatroska(tag, stars); return true; },
                 },
                 ratingStore(f, true));
}

int TagRatingStarsInDictionary(NSDictionary *dictionary) {
    NSString *value = [dictionary objectForKey:@"RATING"];

    if (value == nil)
        return 0;

    int v = [value intValue];
    return (v >= TagRatingMinStars && v <= TagRatingMaxStars) ? v : 0;
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

    if (!TagRatingWriteToFile(fileRef.file(), stars))
        return NO;
    return FileSave::save(fileRef.file());
}

@end
