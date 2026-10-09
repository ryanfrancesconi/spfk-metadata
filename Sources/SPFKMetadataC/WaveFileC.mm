// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#include <fstream>
#include <map>
#include <iostream>
#include <string>
#include <vector>

#import <taglib/privateframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tpropertymap.h>
#import <taglib/wavfile.h>

#import "ID3File.h"
#import "TagFile.h"
#import "TagRating.h"
#import "TagRatingFile.h"
#import "TagUtil.h"
#import "IFFChunkPlanner.h"
#import "WaveFileC.h"
#import "WaveMarkerChunks.h"

@implementation WaveFileC

using namespace std;
using namespace TagLib;

- (instancetype)init {
    self = [super init];
    _id3Properties = [[NSMutableDictionary alloc] init];
    _infoDictionary = [[NSMutableDictionary alloc] init];
    _bextDescriptionC = NULL;
    _tagsNeedsSave = YES;
    _bextNeedsSave = YES;
    _iXMLNeedsSave = YES;
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
    return [self read:true];
}

- (bool)loadTags {
    return [self read:false];
}

/// The tags and audio properties, and with `everything` the other components too.
- (bool)read:(bool)everything {
    WaveMarkerFile file(_path.UTF8String);

    if (!file.isValid()) {
        return false;
    }

    WaveMarkerFile *waveFile = &file;

    [_id3Properties removeAllObjects];
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

    if (everything) {
        [self readComponentsFrom:*waveFile];
    }

    if (waveFile->hasInfoTag()) {
        auto infoMap = waveFile->InfoTag()->fieldListMap();
        _infoDictionary = TagUtil::convertToDictionary(infoMap);
    }

    if (waveFile->hasID3v2Tag()) {
        for (const auto &[key, values] : waveFile->ID3v2Tag()->properties()) {
            [_id3Properties setValue:@(values.toString().toCString(true)) ?: @"" forKey:@(key.toCString(true))];
        }
    }

    // Outside the PropertyMap; see TagRatingFile.h.
    int ratingStars = TagRatingReadFromFile(waveFile);
    if (ratingStars >= 1) {
        [_id3Properties setValue:[NSString stringWithFormat:@"%d", ratingStars] forKey:@"RATING"];
    }

    return true;
}

/// Markers, BEXT, iXML, the XMP packet and the artwork.
- (void)readComponentsFrom:(WaveMarkerFile &)file {
    WaveMarkerFile *waveFile = &file;

    _markers = WaveMarkers::read(*waveFile);

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

    ByteVector xmp = waveFile->xmpData();
    _xmpPacket = xmp.isEmpty() ? nil : [[NSString alloc] initWithBytes:xmp.data() length:xmp.size() encoding:NSUTF8StringEncoding];

    TagPictureRef *pictureRef = [TagPicture readFromTag:waveFile->tag()];
    if (pictureRef) {
        _tagPicture = [[TagPicture alloc] initWithPicture:pictureRef];
    }
}

- (bool)save {
    _failedComponents = WaveFileComponentsNone;

    WaveMarkerFile file(_path.UTF8String);

    if (!file.isValid() || file.readOnly()) {
        _failedComponents = WaveFileComponentsContainer;
        return false;
    }

    std::vector<IFFChunkPlanner::Edit> edits;

    if (_markersNeedsSave && !WaveMarkers::render(file, _markers, edits)) {
        _failedComponents |= WaveFileComponentsMarkers;
    }

    if (_xmpNeedsSave) {
        const ByteVector packet = _xmpPacket.length > 0 ? ByteVector(_xmpPacket.UTF8String) : ByteVector();
        edits.push_back({ "_PMX", ByteVector(), packet.isEmpty() ? std::nullopt : std::optional<ByteVector>(packet) });
    }

    if (_bextNeedsSave && _bextDescriptionC) {
        NSData *bextData = [_bextDescriptionC serializedData];
        file.setBEXTData(ByteVector((const char *)bextData.bytes, (unsigned int)bextData.length));
    } else if (_bextNeedsSave) {
        file.setBEXTData(ByteVector());
    }

    // An empty String removes the chunk.
    if (_iXMLNeedsSave) {
        file.setiXMLData(_iXML ? String(_iXML.UTF8String, String::UTF8) : String());
    }

    // Before the artwork, which `TagFile` would otherwise keep as it was.
    if (_tagsNeedsSave && ![self writeTagsToFile:file]) {
        _failedComponents |= WaveFileComponentsRating;
    } else if (!_tagsNeedsSave && _ratingNeedsSave && ![self writeRatingToFile:file]) {
        _failedComponents |= WaveFileComponentsRating;
    }

    if (_imageNeedsSave && ![TagPicture write:_tagPicture.pictureRef toTag:file.tag()]) {
        _failedComponents |= WaveFileComponentsArtwork;
    }

    const bool tags = _tagsNeedsSave || _ratingNeedsSave;
    const IFFChunkPlanner::WaveChunks chunks = { _bextNeedsSave, _iXMLNeedsSave, tags || _imageNeedsSave, tags };

    if (!IFFChunkPlanner::save(file, edits, chunks)) {
        _failedComponents = WaveFileComponentsContainer;
    }

    return _failedComponents == WaveFileComponentsNone;
}

/// `infoDictionary`'s fields set, an empty value removing its field, and nothing else.
- (bool)writeRatingToFile:(WaveMarkerFile &)file {
    for (NSString *key in _infoDictionary) {
        NSString *value = _infoDictionary[key];
        file.InfoTag()->setFieldText(String(key.UTF8String, String::UTF8).data(String::UTF8), String(value.UTF8String, String::UTF8));
    }

    return TagRatingWriteToFile(&file, TagRatingStarsInDictionary(_id3Properties));
}

/// False only when the rating cannot be written.
- (bool)writeTagsToFile:(WaveMarkerFile &)file {
    // INFO holds one value per field, so a mirror of an unedited list takes its first value.
    std::map<String, String> listFronts;

    for (const auto &[key, values] : file.ID3v2Tag()->properties()) {
        NSString *value = _id3Properties[@(key.toCString(true))];
        if (values.size() > 1 && value && String(value.UTF8String, String::UTF8) == values.toString())
            listFronts[values.toString()] = values.front();
    }

    TagFile *tagFile = [[TagFile alloc] initWithPath:_path];
    tagFile.dictionary = _id3Properties;
    const bool written = [tagFile writeToFile:&file];

    RIFF::Info::Tag *info = file.InfoTag();
    const RIFF::Info::FieldListMap fields = info->fieldListMap();

    for (const auto &[id, _] : fields) {
        NSString *key = [[NSString alloc] initWithBytes:id.data() length:id.size() encoding:NSUTF8StringEncoding];
        NSString *kept = key && !_infoDictionary[key] ? _id3Properties[key] : nil;

        if (kept)
            info->setFieldText(id, String(kept.UTF8String, String::UTF8));
        else
            info->removeField(id);
    }

    for (NSString *key in _infoDictionary) {
        const String value(((NSString *)_infoDictionary[key]).UTF8String, String::UTF8);
        const auto front = listFronts.find(value);
        info->setFieldText(String(key.UTF8String, String::UTF8).data(String::UTF8), front == listFronts.end() ? value : front->second);
    }

    return written;
}

@end
