// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <libkern/OSByteOrder.h>
#import <sndfile/sndfile.hh>

#import "AudioMarker.h"
#import "AudioMarkerUtil.h"
#import "BEXTDescriptionC.h"
#import "StringUtil.h"

// EBU Tech 3285 BEXT chunk binary layout offsets
static const NSUInteger kBEXTMinSize            = 602;
static const NSUInteger kBEXTDescriptionOffset  = 0;
static const NSUInteger kBEXTDescriptionSize    = 256;
static const NSUInteger kBEXTOriginatorOffset   = 256;
static const NSUInteger kBEXTOriginatorSize     = 32;
static const NSUInteger kBEXTOriginatorRefOffset = 288;
static const NSUInteger kBEXTOriginatorRefSize  = 32;
static const NSUInteger kBEXTOriginDateOffset   = 320;
static const NSUInteger kBEXTOriginDateSize     = 10;
static const NSUInteger kBEXTOriginTimeOffset   = 330;
static const NSUInteger kBEXTOriginTimeSize     = 8;
static const NSUInteger kBEXTTimeRefLowOffset   = 338;
static const NSUInteger kBEXTTimeRefHighOffset  = 342;
static const NSUInteger kBEXTVersionOffset      = 346;
static const NSUInteger kBEXTUMIDOffset         = 348;
static const NSUInteger kBEXTUMIDSize           = 64;
static const NSUInteger kBEXTLoudnessValueOffset     = 412;
static const NSUInteger kBEXTLoudnessRangeOffset     = 414;
static const NSUInteger kBEXTMaxTruePeakOffset       = 416;
static const NSUInteger kBEXTMaxMomentaryOffset      = 418;
static const NSUInteger kBEXTMaxShortTermOffset      = 420;
static const NSUInteger kBEXTReservedOffset     = 422;
static const NSUInteger kBEXTReservedSize       = 180;
static const NSUInteger kBEXTCodingHistoryOffset = 602;

@implementation BEXTDescriptionC

using namespace std;

#define BUFFER_LEN 1024

- (double)timeReferenceInSeconds {
    if (_sampleRate <= 0) return 0;
    return (double)_timeReference / _sampleRate;
}

- (instancetype)init {
    self = [super init];
    return self;
}

- (nullable instancetype)initWithData:(nonnull NSData *)data {
    if (data.length < kBEXTMinSize) {
        return nil;
    }

    self = [super init];
    if (!self) return nil;

    const uint8_t *bytes = (const uint8_t *)data.bytes;

    _sequenceDescription = StringUtil::asciiString((const char *)bytes + kBEXTDescriptionOffset,
                                                    kBEXTDescriptionSize);
    _originator = StringUtil::asciiString((const char *)bytes + kBEXTOriginatorOffset,
                                          kBEXTOriginatorSize);
    _originatorReference = StringUtil::asciiString((const char *)bytes + kBEXTOriginatorRefOffset,
                                                    kBEXTOriginatorRefSize);
    _originationDate = StringUtil::asciiString((const char *)bytes + kBEXTOriginDateOffset,
                                               kBEXTOriginDateSize);
    _originationTime = StringUtil::asciiString((const char *)bytes + kBEXTOriginTimeOffset,
                                               kBEXTOriginTimeSize);

    _timeReferenceLow = OSReadLittleInt32(bytes, kBEXTTimeRefLowOffset);
    _timeReferenceHigh = OSReadLittleInt32(bytes, kBEXTTimeRefHighOffset);
    _version = (short)OSReadLittleInt16(bytes, kBEXTVersionOffset);

    _timeReference = (uint64_t(_timeReferenceHigh) << 32) | _timeReferenceLow;

    if (_version >= 1) {
        std::string buffer;
        for (NSUInteger i = 0; i < kBEXTUMIDSize; i++) {
            buffer += StringUtil::charToHexString(bytes[kBEXTUMIDOffset + i]);
        }
        _umid = StringUtil::utf8NSString(buffer);
    }

    if (_version >= 2) {
        _loudnessIntegrated = (double)((int16_t)OSReadLittleInt16(bytes, kBEXTLoudnessValueOffset)) / 100.0;
        _loudnessRange = (double)((int16_t)OSReadLittleInt16(bytes, kBEXTLoudnessRangeOffset)) / 100.0;
        _maxTruePeakLevel = (float)((int16_t)OSReadLittleInt16(bytes, kBEXTMaxTruePeakOffset)) / 100.0f;
        _maxMomentaryLoudness = (double)((int16_t)OSReadLittleInt16(bytes, kBEXTMaxMomentaryOffset)) / 100.0;
        _maxShortTermLoudness = (double)((int16_t)OSReadLittleInt16(bytes, kBEXTMaxShortTermOffset)) / 100.0;
    }

    if (data.length > kBEXTCodingHistoryOffset) {
        _codingHistory = StringUtil::asciiString(
            (const char *)bytes + kBEXTCodingHistoryOffset,
            data.length - kBEXTCodingHistoryOffset);

        if (!_codingHistory) {
            _codingHistory = @"";
        }
    } else {
        _codingHistory = @"";
    }

    return self;
}

- (nonnull NSData *)serializedData {
    NSUInteger codingHistoryLength = 0;
    const char *codingHistoryCStr = NULL;

    if (_codingHistory.length > 0) {
        codingHistoryCStr = StringUtil::asciiCString(_codingHistory);
        if (codingHistoryCStr) {
            codingHistoryLength = strlen(codingHistoryCStr);
        }
    }

    NSUInteger totalSize = kBEXTMinSize + codingHistoryLength;
    NSMutableData *buffer = [NSMutableData dataWithLength:totalSize];
    uint8_t *bytes = (uint8_t *)buffer.mutableBytes;

    // description
    const char *desc = StringUtil::asciiCString(_sequenceDescription);
    if (desc) {
        StringUtil::strncpy_validate((char *)bytes + kBEXTDescriptionOffset,
                                     desc, kBEXTDescriptionSize);
    }

    // originator
    const char *orig = StringUtil::asciiCString(_originator);
    if (orig) {
        StringUtil::strncpy_validate((char *)bytes + kBEXTOriginatorOffset,
                                     orig, kBEXTOriginatorSize);
    }

    // originator reference
    const char *origRef = StringUtil::asciiCString(_originatorReference);
    if (origRef) {
        StringUtil::strncpy_validate((char *)bytes + kBEXTOriginatorRefOffset,
                                     origRef, kBEXTOriginatorRefSize);
    }

    // origination date
    const char *date = StringUtil::asciiCString(_originationDate);
    if (date) {
        StringUtil::strncpy_pad0((char *)bytes + kBEXTOriginDateOffset,
                                 date, kBEXTOriginDateSize, false);
    }

    // origination time
    const char *time = StringUtil::asciiCString(_originationTime);
    if (time) {
        StringUtil::strncpy_pad0((char *)bytes + kBEXTOriginTimeOffset,
                                 time, kBEXTOriginTimeSize, false);
    }

    // time reference
    OSWriteLittleInt32(bytes, kBEXTTimeRefLowOffset, _timeReferenceLow);
    OSWriteLittleInt32(bytes, kBEXTTimeRefHighOffset, _timeReferenceHigh);

    // version
    OSWriteLittleInt16(bytes, kBEXTVersionOffset, (uint16_t)_version);

    // UMID — stored as raw bytes, property holds hex-encoded string
    if (_version >= 1 && _umid.length > 0) {
        const char *umidHex = StringUtil::asciiCString(_umid);
        if (umidHex) {
            StringUtil::hexToBytes(umidHex,
                                   bytes + kBEXTUMIDOffset,
                                   kBEXTUMIDSize);
        }
    }

    // loudness (version 2+)
    if (_version >= 2) {
        OSWriteLittleInt16(bytes, kBEXTLoudnessValueOffset, (uint16_t)(int16_t)(_loudnessIntegrated * 100));
        OSWriteLittleInt16(bytes, kBEXTLoudnessRangeOffset, (uint16_t)(int16_t)(_loudnessRange * 100));
        OSWriteLittleInt16(bytes, kBEXTMaxTruePeakOffset, (uint16_t)(int16_t)(_maxTruePeakLevel * 100));
        OSWriteLittleInt16(bytes, kBEXTMaxMomentaryOffset, (uint16_t)(int16_t)(_maxMomentaryLoudness * 100));
        OSWriteLittleInt16(bytes, kBEXTMaxShortTermOffset, (uint16_t)(int16_t)(_maxShortTermLoudness * 100));
    }

    // coding history
    if (codingHistoryCStr && codingHistoryLength > 0) {
        memcpy(bytes + kBEXTCodingHistoryOffset, codingHistoryCStr, codingHistoryLength);
    }

    return [buffer copy];
}

- (nullable instancetype)initWithPath:(nonnull NSString *)path {
    SF_BROADCAST_INFO bext = {};
    SF_INFO sfinfo = {};
    SNDFILE *infile = sf_open(path.UTF8String, SFM_READ, &sfinfo);

    if (SF_FALSE == sf_command(infile, SFC_GET_BROADCAST_INFO, &bext, sizeof(bext))) {
        cerr << "Failed to read BEXT from file: " <<
            [path cStringUsingEncoding:NSUTF8StringEncoding] << endl;
        sf_close(infile);
        return nil;
    }

    self = [super init];

    _version = bext.version;
    _codingHistory = @(bext.coding_history);

    if (_version >= 2) {
        // A 16-bit signed integer, equal to round(100x the Integrated Loudness
        // Value of the file in LUFS).
        _loudnessIntegrated = ((float)bext.loudness_value) / 100;

        // A 16-bit signed integer, equal to round(100x the Loudness Range of
        // the file in LU).
        _loudnessRange = ((float)bext.loudness_range) / 100;

        // A 16-bit signed integer, equal to round(100x the Maximum True Peak
        // Value of the file in dBTP).
        _maxTruePeakLevel = ((float)bext.max_true_peak_level) / 100;

        // A 16-bit signed integer, equal to round(100x the highest value of the
        // Momentary Loudness Level of the file in LUFS).
        _maxMomentaryLoudness = ((float)bext.max_momentary_loudness) / 100;

        // A 16-bit signed integer, equal to round(100x the highest value of the
        // Short-term Loudness Level of the file in LUFS).
        _maxShortTermLoudness = ((float)bext.max_shortterm_loudness) / 100;
    }

    _sequenceDescription = StringUtil::asciiString(bext.description, sizeof(bext.description));
    _originator = StringUtil::asciiString(bext.originator, sizeof(bext.originator));
    _originationDate = StringUtil::asciiString(bext.origination_date, sizeof(bext.origination_date));
    _originationTime = StringUtil::asciiString(bext.origination_time, sizeof(bext.origination_time));
    _originatorReference = StringUtil::asciiString(bext.originator_reference, sizeof(bext.originator_reference));
    _timeReferenceLow = (uint32_t)bext.time_reference_low;
    _timeReferenceHigh = (uint32_t)bext.time_reference_high;

    _timeReference = (uint64_t(self.timeReferenceHigh) << 32) | self.timeReferenceLow;
    _sampleRate = double(sfinfo.samplerate);

    if (_version >= 1) {
        // Calculate the actual size of the array [64]
        int length = MIN(64, sizeof(bext.umid) / sizeof(bext.umid[0]));

        std::string buffer;

        for (int i = 0; i < length; i++) {
            // Convert the char array to 2 digit hex
            buffer += StringUtil::charToHexString(bext.umid[i]);
        }

        _umid = StringUtil::utf8NSString(buffer);
    }

    sf_close(infile);

    return self;
}

+ (bool)write:(BEXTDescriptionC *)info path:(nonnull NSString *)path {
    NSString *pathExtension = path.pathExtension;
    NSString *outpath = [path stringByDeletingPathExtension];

    outpath = [outpath stringByAppendingString:@"_temp"];
    outpath = [outpath stringByAppendingPathExtension:pathExtension];

    SF_INFO sfinfo = {};
    SNDFILE *infile = sf_open(path.UTF8String, SFM_READ, &sfinfo);
    SNDFILE *outfile = sf_open(outpath.UTF8String, SFM_WRITE, &sfinfo);
    SF_BROADCAST_INFO bext = {};

    bext.version = info.version;

    const char *umid = StringUtil::asciiCString(info.umid);
    const char *codingHistory = StringUtil::asciiCString(info.codingHistory);
    const char *sequenceDescription = StringUtil::asciiCString(info.sequenceDescription);
    const char *originator = StringUtil::asciiCString(info.originator);
    const char *originatorReference = StringUtil::asciiCString(info.originatorReference);
    const char *originationDate = StringUtil::asciiCString(info.originationDate);
    const char *originationTime = StringUtil::asciiCString(info.originationTime);

    if (codingHistory) {
        size_t chsize = StringUtil::strncpy_validate(bext.coding_history,
                                                     codingHistory,
                                                     sizeof(bext.coding_history));
        bext.coding_history_size = (uint32_t)chsize;
    }

    if (info.version >= 1 && umid) {
        StringUtil::strncpy_pad0(bext.umid, umid,
                                 sizeof(bext.umid), true);
    }

    if (sequenceDescription) {
        StringUtil::strncpy_validate(bext.description,
                                     sequenceDescription,
                                     sizeof(bext.description));
    }

    if (originator) {
        StringUtil::strncpy_validate(bext.originator,
                                     originator,
                                     sizeof(bext.originator));
    }

    if (originatorReference) {
        StringUtil::strncpy_validate(bext.originator_reference,
                                     originatorReference,
                                     sizeof(bext.originator_reference));
    }

    if (originationDate) {
        StringUtil::strncpy_pad0(bext.origination_date,
                                 originationDate,
                                 sizeof(bext.origination_date), false);
    }

    if (originationTime) {
        StringUtil::strncpy_pad0(bext.origination_time,
                                 originationTime,
                                 sizeof(bext.origination_time), false);
    }

    if (bext.version >= 2) {
        bext.loudness_value = (int16_t)(info.loudnessIntegrated * 100);
        bext.loudness_range = (int16_t)(info.loudnessRange * 100);
        bext.max_true_peak_level = (int16_t)(info.maxTruePeakLevel * 100);
        bext.max_momentary_loudness = (int16_t)(info.maxMomentaryLoudness * 100);
        bext.max_shortterm_loudness = (int16_t)(info.maxShortTermLoudness * 100);
    }

    bext.time_reference_low = info.timeReferenceLow;
    bext.time_reference_high = info.timeReferenceHigh;

    if (SF_FALSE == sf_command(outfile, SFC_SET_BROADCAST_INFO, &bext, sizeof(bext))) {
        cerr << "Failed to write BEXT to file " << outpath << endl;
        sf_close(infile);
        sf_close(outfile);
        return false;
    }

    int readcount;
    double data[BUFFER_LEN];

    // copy samples to file
    while ((readcount = (int)sf_read_double(infile, data, BUFFER_LEN)))
        sf_write_double(outfile, data, readcount);

    sf_close(infile);
    sf_close(outfile);

    NSURL *inputURL = [NSURL fileURLWithPath:path];
    NSURL *outputURL = [NSURL fileURLWithPath:outpath];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSError *error = nil;

    if ([fileManager removeItemAtURL:inputURL error:&error]) {
        NSLog(@"File removed successfully");
    } else {
        NSLog(@"Error removing file: %@", error.localizedDescription);
        return false;
    }

    error = nil;
    BOOL success = [fileManager moveItemAtURL:outputURL
                                        toURL:inputURL
                                        error:&error];

    if (!success) {
        NSLog(@"Error moving temp file: %@", error.localizedDescription);
    }

    return success;
}

@end
