// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <iostream>

#import <taglib/fileref.h>
#import <taglib/flacfile.h>

#import "BEXTDescriptionC.h"
#import "FlacFileC.h"
#import "TagAudioPropertiesC.h"

@implementation FlacFileC

using namespace std;
using namespace TagLib;

- (instancetype)initWithPath:(nonnull NSString *)path {
    self = [super init];
    _path = path;
    return self;
}

- (bool)load {
    FileRef fileRef(_path.UTF8String);

    if (fileRef.isNull()) {
        return false;
    }

    auto *flacFile = dynamic_cast<FLAC::File *>(fileRef.file());

    if (!flacFile) {
        return false;
    }

    auto audioProperties = fileRef.audioProperties();

    if (audioProperties != nullptr) {
        _audioPropertiesC = [[TagAudioPropertiesC alloc] init];
        _audioPropertiesC.sampleRate = (double)audioProperties->sampleRate();
        _audioPropertiesC.duration = (double)audioProperties->lengthInMilliseconds() / 1000;
        _audioPropertiesC.bitRate = audioProperties->bitrate();
        _audioPropertiesC.channelCount = audioProperties->channels();

        auto *flacProps = flacFile->audioProperties();
        if (flacProps) {
            _audioPropertiesC.bitsPerSample = flacProps->bitsPerSample();
        }
    }

    if (flacFile->hasBEXTData() && !flacFile->BEXTData().isEmpty()) {
        ByteVector bext = flacFile->BEXTData();
        NSData *bextData = [NSData dataWithBytes:bext.data() length:bext.size()];
        _bextDescriptionC = [[BEXTDescriptionC alloc] initWithData:bextData];

        if (_bextDescriptionC && _audioPropertiesC) {
            _bextDescriptionC.sampleRate = _audioPropertiesC.sampleRate;
        }
    }

    if (flacFile->hasiXMLData()) {
        _iXML = [[NSString alloc] initWithCString:flacFile->iXMLData().data(String::UTF8).data()
                                         encoding:NSUTF8StringEncoding];
    }

    return true;
}

- (bool)save {
    FileRef fileRef(_path.UTF8String);

    if (fileRef.isNull()) {
        cout << "FlacFileC: FileRef is nil for " << _path.UTF8String << endl;
        return false;
    }

    auto *flacFile = dynamic_cast<FLAC::File *>(fileRef.file());

    if (!flacFile) {
        cout << "FlacFileC: Not a FLAC file: " << _path.UTF8String << endl;
        return false;
    }

    if (_bextDescriptionC) {
        NSData *bextData = [_bextDescriptionC serializedData];
        flacFile->setBEXTData(ByteVector((const char *)bextData.bytes, (unsigned int)bextData.length));
    } else {
        flacFile->setBEXTData(ByteVector());
    }

    flacFile->setiXMLData(_iXML ? String(_iXML.UTF8String) : String());

    return flacFile->save();
}

@end
