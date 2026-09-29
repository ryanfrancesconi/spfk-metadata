// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#import <taglib/privateframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>
#import <taglib/wavfile.h>

#import "AudioMarkerUtil.h"
#import "ID3File.h"
#import "TagFile.h"
#import "TagRating.h"
#import "TagUtil.h"
#import "WaveFileC.h"
#import "WaveMarkerChunks.h"

// Forward declarations — implementations live in TagRating.mm.
int TagRatingReadFromFile(TagLib::File *f);
void TagRatingWriteToFile(TagLib::File *f, int stars);

@implementation WaveFileC

using namespace std;
using namespace TagLib;

- (instancetype)init {
    self = [super init];
    _id3Dictionary = [[NSMutableDictionary alloc] init];
    _infoDictionary = [[NSMutableDictionary alloc] init];
    _bextDescriptionC = NULL;
    _markersNeedsSave = YES;
    _imageNeedsSave = YES;

    return self;
}

- (instancetype)initWithPath:(nonnull NSString *)path {
    self = [super init];

    _path = path;
    _id3Dictionary = [[NSMutableDictionary alloc] init];
    _infoDictionary = [[NSMutableDictionary alloc] init];
    _bextDescriptionC = NULL;
    _markersNeedsSave = YES;
    _imageNeedsSave = YES;

    return self;
}

- (bool)load {
    WaveMarkerFile file(_path.UTF8String);

    if (!file.isValid()) {
        return false;
    }

    WaveMarkerFile *waveFile = &file;

    [_id3Dictionary removeAllObjects];
    [_infoDictionary removeAllObjects];

    auto audioProperties = waveFile->audioProperties();

    if (audioProperties != nullptr) {
        _audioPropertiesC = [[TagAudioPropertiesC alloc] init];
        _audioPropertiesC.sampleRate = (double)audioProperties->sampleRate();
        _audioPropertiesC.duration = (double)audioProperties->lengthInMilliseconds() / 1000;
        _audioPropertiesC.bitRate = audioProperties->bitrate();
        _audioPropertiesC.channelCount = audioProperties->channels();

        auto *wavProps = waveFile->audioProperties();
        if (wavProps) {
            _audioPropertiesC.bitsPerSample = wavProps->bitsPerSample();
        }
    }

    NSURL *url = [NSURL fileURLWithPath:_path];
    _markers = [WaveMarkerChunks isRIFFWave:url] ? WaveMarkers::read(*waveFile) : [AudioMarkerUtil read:url];

    if (waveFile->hasBEXTData() && !waveFile->BEXTData().isEmpty()) {
        ByteVector bext = waveFile->BEXTData();
        NSData *bextData = [NSData dataWithBytes:bext.data() length:bext.size()];
        _bextDescriptionC = [[BEXTDescriptionC alloc] initWithData:bextData];

        if (_bextDescriptionC && _audioPropertiesC) {
            _bextDescriptionC.sampleRate = _audioPropertiesC.sampleRate;
        }
    }

    if (waveFile->hasiXMLData()) {
        _iXML = [[NSString alloc] initWithCString:waveFile->iXMLData().data(String::UTF8).data()
                                         encoding:NSUTF8StringEncoding];
    }

    if (waveFile->hasInfoTag()) {
        auto infoMap = waveFile->InfoTag()->fieldListMap();
        _infoDictionary = TagUtil::convertToDictionary(infoMap);
    }

    if (waveFile->hasID3v2Tag()) {
        ID3v2::Tag *tag = waveFile->ID3v2Tag();
        ID3v2::FrameList frameList = tag->frameList();
        _id3Dictionary = TagUtil::convertToDictionary(frameList);
    }

    TagPictureRef *pictureRef = [TagPicture readFromTag:waveFile->tag()];
    if (pictureRef) {
        _tagPicture = [[TagPicture alloc] initWithPicture:pictureRef];
    }

    // Inject rating via dedicated dispatch; avoids a second FileRef open after load returns.
    int ratingStars = TagRatingReadFromFile(waveFile);
    if (ratingStars >= 1) {
        [_id3Dictionary setValue:[NSString stringWithFormat:@"%d", ratingStars] forKey:@"RATING"];
    }

    return true;
}

- (bool)save {
    bool isRIFFWave = [WaveMarkerChunks isRIFFWave:[NSURL fileURLWithPath:_path]];
    bool markersSaved = isRIFFWave ? true : [self saveExtras];

    WaveMarkerFile file(_path.UTF8String);

    if (!file.isValid()) {
        cout << "Not a wave file" << endl;
        return false;
    }

    WaveMarkerFile *waveFile = &file;

    if (isRIFFWave && _markersNeedsSave) {
        markersSaved = WaveMarkers::write(*waveFile, _markers);
    }

    // write bext via TagLib chunk (no more temp file + audio copy)
    if (_bextDescriptionC) {
        NSData *bextData = [_bextDescriptionC serializedData];
        waveFile->setBEXTData(ByteVector((const char *)bextData.bytes, (unsigned int)bextData.length));
    } else {
        waveFile->setBEXTData(ByteVector());
    }

    // write ixml (empty String triggers chunk removal in wavfile.cpp)
    waveFile->setiXMLData(_iXML ? String(_iXML.UTF8String, String::UTF8) : String());

    // write artwork via the same TagLib session (skip if not dirty)
    if (_imageNeedsSave) {
        [TagPicture write:_tagPicture.pictureRef toTag:waveFile->tag()];
    }

    // Extract rating before PropertyMap conversion — RATING is routed through the
    // POPM frame via TagRatingWriteToFile, not through setProperties.
    // Default to 0 so an absent key clears any existing POPM frame (rating removed).
    int ratingStars = 0;
    NSString *ratingValue = [_id3Dictionary objectForKey:@"RATING"];
    if (ratingValue != nil) {
        int v = [ratingValue intValue];
        if (v >= TagRatingMinStars && v <= TagRatingMaxStars)
            ratingStars = v;
    }

    NSMutableDictionary *filteredDict = [NSMutableDictionary dictionaryWithDictionary:_id3Dictionary];
    [filteredDict removeObjectForKey:@"RATING"];
    PropertyMap properties = TagUtil::convertToPropertyMap(filteredDict);
    waveFile->ID3v2Tag()->setProperties(properties);

    // clear all existing INFO fields first, then write new ones
    {
        auto existingInfoFields = waveFile->InfoTag()->fieldListMap();
        for (const auto &pair : existingInfoFields) {
            waveFile->InfoTag()->removeField(pair.first);
        }
    }

    for (NSString *key in [_infoDictionary allKeys]) {
        NSString *value = [_infoDictionary objectForKey:key];

        ByteVector tagKey = String(key.UTF8String, String::UTF8).data(String::UTF8);
        String tagValue = String(value.UTF8String, String::UTF8);

        waveFile->InfoTag()->setFieldText(tagKey, tagValue);
    }

    if (ratingStars >= 0)
        TagRatingWriteToFile(waveFile, ratingStars);

    // save via taglib
    bool tagsSaved = waveFile->save();
    return tagsSaved && markersSaved;
}

/// Formats other than RIFF WAVE (RF64, BW64) write markers through Core Audio, before TagLib opens the file.
- (bool)saveExtras {
    if (_markersNeedsSave) {
        NSURL *url = [NSURL fileURLWithPath:_path];
        return [AudioMarkerUtil write:_markers to:url];
    }

    return true;
}

@end
