// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagRatingStores_H
#define TagRatingStores_H

#import <taglib/apetag.h>
#import <taglib/asftag.h>
#import <taglib/id3v2tag.h>
#import <taglib/matroskatag.h>
#import <taglib/mp4tag.h>
#import <taglib/xiphcomment.h>

/// Each container's rating store. A read returns stars, or -1 when nothing is stored; a write of 0
/// clears the rating. A null tag is nothing to do.
namespace TagRatingStores {
int readID3(TagLib::ID3v2::Tag *tag);
void writeID3(TagLib::ID3v2::Tag *tag, int stars);

int readXiph(TagLib::Ogg::XiphComment *xiph);
void writeXiph(TagLib::Ogg::XiphComment *xiph, int stars);

int readMP4(TagLib::MP4::Tag *tag);
void writeMP4(TagLib::MP4::Tag *tag, int stars);

int readAPE(TagLib::APE::Tag *tag);
void writeAPE(TagLib::APE::Tag *tag, int stars);

int readMatroska(TagLib::Matroska::Tag *tag);
void writeMatroska(TagLib::Matroska::Tag *tag, int stars);

int readASF(TagLib::ASF::Tag *tag);
void writeASF(TagLib::ASF::Tag *tag, int stars);
} // namespace TagRatingStores

#endif
