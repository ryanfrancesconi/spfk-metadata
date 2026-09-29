// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <libkern/OSByteOrder.h>

#import "BEXTDescriptionC.h"
#import "StringUtil.h"

// EBU Tech 3285 layout.
static const NSUInteger kBEXTMinSize = 602;
static const NSUInteger kBEXTDescriptionOffset = 0;
static const NSUInteger kBEXTDescriptionSize = 256;
static const NSUInteger kBEXTOriginatorOffset = 256;
static const NSUInteger kBEXTOriginatorSize = 32;
static const NSUInteger kBEXTOriginatorRefOffset = 288;
static const NSUInteger kBEXTOriginatorRefSize = 32;
static const NSUInteger kBEXTOriginDateOffset = 320;
static const NSUInteger kBEXTOriginDateSize = 10;
static const NSUInteger kBEXTOriginTimeOffset = 330;
static const NSUInteger kBEXTOriginTimeSize = 8;
static const NSUInteger kBEXTTimeRefLowOffset = 338;
static const NSUInteger kBEXTTimeRefHighOffset = 342;
static const NSUInteger kBEXTVersionOffset = 346;
static const NSUInteger kBEXTUMIDOffset = 348;
static const NSUInteger kBEXTUMIDSize = 64;
static const NSUInteger kBEXTLoudnessValueOffset = 412;
static const NSUInteger kBEXTLoudnessRangeOffset = 414;
static const NSUInteger kBEXTMaxTruePeakOffset = 416;
static const NSUInteger kBEXTMaxMomentaryOffset = 418;
static const NSUInteger kBEXTMaxShortTermOffset = 420;
static const NSUInteger kBEXTReservedOffset = 422;
static const NSUInteger kBEXTReservedSize = 180;
static const NSUInteger kBEXTCodingHistoryOffset = 602;

/// Null-terminated when it fits; a value that is not ASCII is left as zeros.
static void writeText(uint8_t *bytes, NSUInteger offset, NSString *value, NSUInteger size) {
    if (const char *text = StringUtil::asciiCString(value)) {
        StringUtil::strncpy_validate((char *)bytes + offset, text, size);
    }
}

/// Date and time: a short value is padded with the character '0', never terminated.
static void writeFixedText(uint8_t *bytes, NSUInteger offset, NSString *value, NSUInteger size) {
    if (const char *text = StringUtil::asciiCString(value)) {
        StringUtil::strncpy_pad0((char *)bytes + offset, text, size, false);
    }
}

@implementation BEXTDescriptionC

- (double)timeReferenceInSeconds {
    if (_sampleRate <= 0)
        return 0;
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
    if (!self)
        return nil;

    const uint8_t *bytes = (const uint8_t *)data.bytes;

    _sequenceDescription = StringUtil::asciiString((const char *)bytes + kBEXTDescriptionOffset, kBEXTDescriptionSize);
    _originator = StringUtil::asciiString((const char *)bytes + kBEXTOriginatorOffset, kBEXTOriginatorSize);
    _originatorReference =
        StringUtil::asciiString((const char *)bytes + kBEXTOriginatorRefOffset, kBEXTOriginatorRefSize);
    _originationDate = StringUtil::asciiString((const char *)bytes + kBEXTOriginDateOffset, kBEXTOriginDateSize);
    _originationTime = StringUtil::asciiString((const char *)bytes + kBEXTOriginTimeOffset, kBEXTOriginTimeSize);

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
        _codingHistory = StringUtil::asciiString((const char *)bytes + kBEXTCodingHistoryOffset,
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

    writeText(bytes, kBEXTDescriptionOffset, _sequenceDescription, kBEXTDescriptionSize);
    writeText(bytes, kBEXTOriginatorOffset, _originator, kBEXTOriginatorSize);
    writeText(bytes, kBEXTOriginatorRefOffset, _originatorReference, kBEXTOriginatorRefSize);
    writeFixedText(bytes, kBEXTOriginDateOffset, _originationDate, kBEXTOriginDateSize);
    writeFixedText(bytes, kBEXTOriginTimeOffset, _originationTime, kBEXTOriginTimeSize);

    OSWriteLittleInt32(bytes, kBEXTTimeRefLowOffset, _timeReferenceLow);
    OSWriteLittleInt32(bytes, kBEXTTimeRefHighOffset, _timeReferenceHigh);
    OSWriteLittleInt16(bytes, kBEXTVersionOffset, (uint16_t)_version);

    // Raw bytes on disk; the property holds them hex-encoded.
    if (_version >= 1 && _umid.length > 0) {
        const char *umidHex = StringUtil::asciiCString(_umid);
        if (umidHex) {
            StringUtil::hexToBytes(umidHex, bytes + kBEXTUMIDOffset, kBEXTUMIDSize);
        }
    }

    if (_version >= 2) {
        OSWriteLittleInt16(bytes, kBEXTLoudnessValueOffset, (uint16_t)(int16_t)(_loudnessIntegrated * 100));
        OSWriteLittleInt16(bytes, kBEXTLoudnessRangeOffset, (uint16_t)(int16_t)(_loudnessRange * 100));
        OSWriteLittleInt16(bytes, kBEXTMaxTruePeakOffset, (uint16_t)(int16_t)(_maxTruePeakLevel * 100));
        OSWriteLittleInt16(bytes, kBEXTMaxMomentaryOffset, (uint16_t)(int16_t)(_maxMomentaryLoudness * 100));
        OSWriteLittleInt16(bytes, kBEXTMaxShortTermOffset, (uint16_t)(int16_t)(_maxShortTermLoudness * 100));
    }

    if (codingHistoryCStr && codingHistoryLength > 0) {
        memcpy(bytes + kBEXTCodingHistoryOffset, codingHistoryCStr, codingHistoryLength);
    }

    return [buffer copy];
}

@end
