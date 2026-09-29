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
#import "TagRatingFile.h"
#import "TagUtil.h"
#import "WaveFileC.h"
#import "WaveMarkerChunks.h"

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
    self = [self init];
    _path = path;

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
        _audioPropertiesC.bitsPerSample = audioProperties->bitsPerSample();
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

    // Outside the PropertyMap; see TagRatingFile.h.
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

    if (_bextDescriptionC) {
        NSData *bextData = [_bextDescriptionC serializedData];
        waveFile->setBEXTData(ByteVector((const char *)bextData.bytes, (unsigned int)bextData.length));
    } else {
        waveFile->setBEXTData(ByteVector());
    }

    // An empty String removes the chunk.
    waveFile->setiXMLData(_iXML ? String(_iXML.UTF8String, String::UTF8) : String());

    if (_imageNeedsSave) {
        [TagPicture write:_tagPicture.pictureRef toTag:waveFile->tag()];
    }

    // Kept out of the PropertyMap; written as POPM below.
    int ratingStars = TagRatingStarsInDictionary(_id3Dictionary);

    NSMutableDictionary *filteredDict = [NSMutableDictionary dictionaryWithDictionary:_id3Dictionary];
    [filteredDict removeObjectForKey:@"RATING"];
    PropertyMap properties = TagUtil::convertToPropertyMap(filteredDict);
    waveFile->ID3v2Tag()->setProperties(properties);

    // Cleared first, so a field absent from the dictionary is removed.
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

    if (!TagRatingWriteToFile(waveFile, ratingStars))
        return false;

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
