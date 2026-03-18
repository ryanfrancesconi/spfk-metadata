// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#import <taglib/fileref.h>
#import <taglib/privateframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>
#import <taglib/wavfile.h>

#import "AudioMarkerUtil.h"
#import "ID3File.h"
#import "TagFile.h"
#import "TagUtil.h"
#import "WaveFileC.h"

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
    FileRef fileRef(_path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    auto *waveFile = dynamic_cast<RIFF::WAV::File *>(fileRef.file());

    if (!waveFile) {
        // not a wave file
        return false;
    }

    [_id3Dictionary removeAllObjects];
    [_infoDictionary removeAllObjects];

    auto audioProperties = fileRef.audioProperties();

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
    _markers = [AudioMarkerUtil getMarkers:url];

    if (waveFile->hasBEXTTag() && !waveFile->BEXTData().isEmpty()) {
        ByteVector bext = waveFile->BEXTData();
        NSData *bextData = [NSData dataWithBytes:bext.data() length:bext.size()];
        _bextDescriptionC = [[BEXTDescriptionC alloc] initWithData:bextData];

        if (_bextDescriptionC && _audioPropertiesC) {
            _bextDescriptionC.sampleRate = _audioPropertiesC.sampleRate;
        }
    }

    if (waveFile->hasiXMLTag()) {
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

    return true;
}

- (bool)save {
    [self saveExtras];

    FileRef fileRef(_path.UTF8String);

    if (fileRef.isNull()) {
        cout << "FileRef is nil" << endl;
        return false;
    }

    auto *waveFile = dynamic_cast<RIFF::WAV::File *>(fileRef.file());

    if (!waveFile) {
        cout << "Not a wave file" << endl;
        return false;
    }

    // write bext via TagLib chunk (no more temp file + audio copy)
    if (_bextDescriptionC) {
        NSData *bextData = [_bextDescriptionC serializedData];
        waveFile->setBEXTData(ByteVector((const char *)bextData.bytes, (unsigned int)bextData.length));
    } else {
        waveFile->setBEXTData(ByteVector());
    }

    // write ixml (empty String triggers chunk removal in wavfile.cpp)
    waveFile->setiXMLData(_iXML ? String(_iXML.UTF8String) : String());

    // write artwork via the same TagLib session (skip if not dirty)
    if (_imageNeedsSave) {
        [TagPicture write:_tagPicture.pictureRef toTag:waveFile->tag()];
    }

    // write id3
    PropertyMap properties = TagUtil::convertToPropertyMap(_id3Dictionary);
    waveFile->ID3v2Tag()->setProperties(properties);

    // write info values directly
    if (_infoDictionary.count > 0) {
        for (NSString *key in [_infoDictionary allKeys]) {
            NSString *value = [_infoDictionary objectForKey:key];

            ByteVector tagKey = String(key.UTF8String).data(String::UTF8);
            String tagValue = String(value.UTF8String);

            waveFile->InfoTag()->setFieldText(tagKey, tagValue);
        }
    }

    // save via taglib
    return waveFile->save();
}

- (void)saveExtras {
    // write markers (via AudioToolbox, separate from TagLib)
    if (_markersNeedsSave && _markers.count > 0) {
        NSURL *url = [NSURL fileURLWithPath:_path];
        [AudioMarkerUtil update:url markers:_markers];
    }
}

@end
