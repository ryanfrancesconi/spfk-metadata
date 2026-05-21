// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/flacfile.h>
#import <taglib/mp4file.h>
#import <taglib/mpegfile.h>
#import <taglib/opusfile.h>
#import <taglib/rifffile.h>
#import <taglib/tpropertymap.h>
#import <taglib/vorbisfile.h>
#import <taglib/wavfile.h>

#import "StringUtil.h"
#import "TagAudioPropertiesC.h"
#import "TagFile.h"
#import "TagFileType.h"
#import "TagLibBridge.h"
#import "TagRatingUtil.h"

@implementation TagFile

using namespace std;
using namespace TagLib;

- (instancetype)initWithPath:(nonnull NSString *)path {
    self = [super init];

    _path = path;
    _dictionary = [[NSMutableDictionary alloc] init];

    return self;
}

- (bool)load {
    FileRef fileRef(_path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    auto audioProperties = fileRef.audioProperties();

    if (audioProperties != nullptr) {
        _audioProperties = [[TagAudioPropertiesC alloc] init];
        _audioProperties.sampleRate = (double)audioProperties->sampleRate();
        _audioProperties.duration = (double)audioProperties->lengthInMilliseconds() / 1000;
        _audioProperties.bitRate = audioProperties->bitrate();
        _audioProperties.channelCount = audioProperties->channels();
    }

    Tag *tag = fileRef.tag();

    if (!tag) {
        return false;
    }

    PropertyMap properties = tag->properties();

    // Copy TagLib's PropertyMap into our dictionary using the same keys they use.
    // See TagKey for translations.
    // Note: do not early-return when PropertyMap is empty — a file may have only
    // format-specific rating storage (POPM, rate atom) with no other PropertyMap entries.

    for (const auto &property : properties) {
        const char *ckey = property.first.toCString(true);
        String cval = property.second.toString();

        NSString *key = @(ckey);
        NSString *object = @(cval.toCString(true)) ?: @"";

        if (key != nil && object != nil) {
            [_dictionary setValue:object forKey:key];
        }
    }

    // Read format-specific rating (POPM for ID3v2, Xiph for OGG/FLAC, rate atom for MP4).
    // This supplements the PropertyMap which misses POPM and MP4 rate atoms.
    NSString *fileType = [TagFileType detectType:_path];
    int ratingValue = -1;

    if ([fileType isEqualToString:kTagFileTypeMp3]) {
        auto *mpegFile = dynamic_cast<MPEG::File *>(fileRef.file());
        if (mpegFile && mpegFile->ID3v2Tag()) {
            ratingValue = [TagRatingUtil readFromTag:mpegFile->ID3v2Tag() fileType:fileType];
        }
    } else if ([fileType isEqualToString:kTagFileTypeAiff]) {
        auto *aiffFile = dynamic_cast<RIFF::AIFF::File *>(fileRef.file());
        if (aiffFile) {
            ratingValue = [TagRatingUtil readFromTag:aiffFile->tag() fileType:fileType];
        }
    } else if ([fileType isEqualToString:kTagFileTypeM4a] || [fileType isEqualToString:kTagFileTypeMp4] ||
               [fileType isEqualToString:kTagFileTypeAac]) {
        auto *mp4File = dynamic_cast<MP4::File *>(fileRef.file());
        if (mp4File) {
            ratingValue = [TagRatingUtil readFromTag:mp4File->tag() fileType:fileType];
        }
    } else if ([fileType isEqualToString:kTagFileTypeFlac]) {
        auto *flacFile = dynamic_cast<FLAC::File *>(fileRef.file());
        if (flacFile) {
            Ogg::XiphComment *xiph = flacFile->xiphComment(false);
            if (xiph) ratingValue = [TagRatingUtil readFromTag:xiph fileType:fileType];
        }
    } else if ([fileType isEqualToString:kTagFileTypeVorbis]) {
        auto *oggFile = dynamic_cast<Ogg::Vorbis::File *>(fileRef.file());
        if (oggFile) {
            ratingValue = [TagRatingUtil readFromTag:oggFile->tag() fileType:fileType];
        }
    } else if ([fileType isEqualToString:kTagFileTypeOpus]) {
        auto *opusFile = dynamic_cast<Ogg::Opus::File *>(fileRef.file());
        if (opusFile) {
            ratingValue = [TagRatingUtil readFromTag:opusFile->tag() fileType:fileType];
        }
    }

    if (ratingValue > 0) {
        [_dictionary setValue:[NSString stringWithFormat:@"%d", ratingValue] forKey:@"RATING"];
    }

    return true;
}

- (bool)save {
    FileRef fileRef(_path.UTF8String);

    if (fileRef.isNull()) {
        cout << "Unable to read path:" << _path.UTF8String << endl;
        return false;
    }

    // Strip existing tags before writing so that atoms not present in the new
    // dictionary are removed. setProperties alone does not clear format-specific
    // storage like iTunes freeform atoms (e.g. ITUNSMPB in M4A files).
    NSString *fileType = [TagFileType detectType:_path];

    if ([fileType isEqualToString:kTagFileTypeWave]) {
        auto *f = dynamic_cast<RIFF::WAV::File *>(fileRef.file());
        if (f) f->strip();
    } else if ([fileType isEqualToString:kTagFileTypeM4a] || [fileType isEqualToString:kTagFileTypeMp4] ||
               [fileType isEqualToString:kTagFileTypeAac]) {
        auto *f = dynamic_cast<MP4::File *>(fileRef.file());
        if (f) f->strip();
    } else if ([fileType isEqualToString:kTagFileTypeMp3]) {
        auto *f = dynamic_cast<MPEG::File *>(fileRef.file());
        if (f) f->strip();
    } else if ([fileType isEqualToString:kTagFileTypeFlac]) {
        auto *f = dynamic_cast<FLAC::File *>(fileRef.file());
        if (f) f->strip();
    } else {
        fileRef.setProperties(PropertyMap());
    }

    PropertyMap properties = PropertyMap();

    NSString *ratingStr = [_dictionary objectForKey:@"RATING"];
    int rating = ratingStr ? ratingStr.intValue : -1;

    for (NSString *key in [_dictionary allKeys]) {
        // Rating is routed through TagRatingUtil below — skipped here to avoid
        // TXXX:RATING in ID3v2 or wrong freeform atoms in MP4.
        if ([key isEqualToString:@"RATING"]) continue;

        NSString *value = [_dictionary objectForKey:key];
        String tagKey = String(key.UTF8String, String::UTF8);
        StringList tagValue = StringList(String(value.UTF8String, String::UTF8));
        properties.insert(tagKey, tagValue);
    }

    properties.removeEmpty();
    fileRef.setProperties(properties);

    if (rating >= 0) {
        if ([fileType isEqualToString:kTagFileTypeMp3]) {
            auto *mpegFile = dynamic_cast<MPEG::File *>(fileRef.file());
            if (mpegFile) {
                [TagRatingUtil writeToTag:mpegFile->ID3v2Tag(true) fileType:fileType normalized:rating];
            }
        } else if ([fileType isEqualToString:kTagFileTypeAiff]) {
            auto *aiffFile = dynamic_cast<RIFF::AIFF::File *>(fileRef.file());
            if (aiffFile) {
                [TagRatingUtil writeToTag:aiffFile->tag() fileType:fileType normalized:rating];
            }
        } else if ([fileType isEqualToString:kTagFileTypeM4a] || [fileType isEqualToString:kTagFileTypeMp4] ||
                   [fileType isEqualToString:kTagFileTypeAac]) {
            auto *mp4File = dynamic_cast<MP4::File *>(fileRef.file());
            if (mp4File) {
                [TagRatingUtil writeToTag:mp4File->tag() fileType:fileType normalized:rating];
            }
        } else if ([fileType isEqualToString:kTagFileTypeFlac]) {
            auto *flacFile = dynamic_cast<FLAC::File *>(fileRef.file());
            if (flacFile) {
                Ogg::XiphComment *xiph = flacFile->xiphComment(true);
                if (xiph) {
                    [TagRatingUtil writeToTag:xiph fileType:fileType normalized:rating];
                }
            }
        } else if ([fileType isEqualToString:kTagFileTypeVorbis]) {
            auto *oggFile = dynamic_cast<Ogg::Vorbis::File *>(fileRef.file());
            if (oggFile) {
                [TagRatingUtil writeToTag:oggFile->tag() fileType:fileType normalized:rating];
            }
        } else if ([fileType isEqualToString:kTagFileTypeOpus]) {
            auto *opusFile = dynamic_cast<Ogg::Opus::File *>(fileRef.file());
            if (opusFile) {
                [TagRatingUtil writeToTag:opusFile->tag() fileType:fileType normalized:rating];
            }
        }
    }

    return fileRef.save();
}

@end
