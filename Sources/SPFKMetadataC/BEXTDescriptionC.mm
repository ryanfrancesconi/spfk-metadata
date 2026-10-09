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

/// UTF-8, cut to at most `maxBytes` without splitting a character. The spec says ASCII, which
/// encodes identically; anything else is written as UTF-8 rather than dropped.
static std::string encodedText(NSString *value, NSUInteger maxBytes) {
    const char *text = StringUtil::utf8CString(value);
    if (!text) {
        return std::string();
    }

    size_t length = strlen(text);
    if (length > maxBytes) {
        length = maxBytes;
        while (length > 0 && ((uint8_t)text[length] & 0xC0) == 0x80) {
            length--;
        }
    }
    return std::string(text, length);
}

/// Null-terminated when it fits.
static void writeText(uint8_t *bytes, NSUInteger offset, NSString *value, NSUInteger size) {
    StringUtil::strncpy_validate((char *)bytes + offset, encodedText(value, size).c_str(), size);
}

/// Date and time: a short value is padded with the character '0', never terminated. Nil or empty
/// leaves the field zeroed, the form a recorder without a clock writes.
static void writeFixedText(uint8_t *bytes, NSUInteger offset, NSString *value, NSUInteger size) {
    if (value.length == 0) {
        return;
    }

    StringUtil::strncpy_pad0((char *)bytes + offset, encodedText(value, size).c_str(), size, false);
}

/// Nil and empty are the same absent value.
static bool differs(NSString *value, NSString *stored) {
    return ![(value ?: @"") isEqualToString:(stored ?: @"")];
}

/// The field zeroed, then `write`.
static void rewriteText(uint8_t *bytes, NSUInteger offset, NSString *value, NSUInteger size,
                        void (*write)(uint8_t *, NSUInteger, NSString *, NSUInteger)) {
    memset(bytes + offset, 0, size);
    write(bytes, offset, value, size);
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
    std::string codingHistory = encodedText(_codingHistory, NSUIntegerMax);
    NSUInteger codingHistoryLength = codingHistory.size();

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

    if (codingHistoryLength > 0) {
        memcpy(bytes + kBEXTCodingHistoryOffset, codingHistory.data(), codingHistoryLength);
    }

    return [buffer copy];
}

- (nonnull NSData *)serializedDataOver:(nullable NSData *)stored {
    BEXTDescriptionC *read = stored ? [[BEXTDescriptionC alloc] initWithData:stored] : nil;

    if (!read) {
        return [self serializedData];
    }

    NSMutableData *buffer = [[stored subdataWithRange:NSMakeRange(0, kBEXTMinSize)] mutableCopy];

    if (differs(_codingHistory, read.codingHistory)) {
        std::string codingHistory = encodedText(_codingHistory, NSUIntegerMax);
        [buffer appendBytes:codingHistory.data() length:codingHistory.size()];
    } else {
        [buffer appendData:[stored subdataWithRange:NSMakeRange(kBEXTMinSize, stored.length - kBEXTMinSize)]];
    }

    // After the append, which can move the buffer.
    uint8_t *bytes = (uint8_t *)buffer.mutableBytes;

    if (differs(_sequenceDescription, read.sequenceDescription))
        rewriteText(bytes, kBEXTDescriptionOffset, _sequenceDescription, kBEXTDescriptionSize, writeText);
    if (differs(_originator, read.originator))
        rewriteText(bytes, kBEXTOriginatorOffset, _originator, kBEXTOriginatorSize, writeText);
    if (differs(_originatorReference, read.originatorReference))
        rewriteText(bytes, kBEXTOriginatorRefOffset, _originatorReference, kBEXTOriginatorRefSize, writeText);
    if (differs(_originationDate, read.originationDate))
        rewriteText(bytes, kBEXTOriginDateOffset, _originationDate, kBEXTOriginDateSize, writeFixedText);
    if (differs(_originationTime, read.originationTime))
        rewriteText(bytes, kBEXTOriginTimeOffset, _originationTime, kBEXTOriginTimeSize, writeFixedText);

    if (_timeReferenceLow != read.timeReferenceLow)
        OSWriteLittleInt32(bytes, kBEXTTimeRefLowOffset, _timeReferenceLow);
    if (_timeReferenceHigh != read.timeReferenceHigh)
        OSWriteLittleInt32(bytes, kBEXTTimeRefHighOffset, _timeReferenceHigh);
    if (_version != read.version)
        OSWriteLittleInt16(bytes, kBEXTVersionOffset, (uint16_t)_version);

    // A field the version does not define keeps its bytes as stored; one it newly defines is written.
    if (_version >= 1 && (read.version < 1 || differs(_umid, read.umid))) {
        memset(bytes + kBEXTUMIDOffset, 0, kBEXTUMIDSize);
        const char *umidHex = _umid.length > 0 ? StringUtil::asciiCString(_umid) : NULL;
        if (umidHex) {
            StringUtil::hexToBytes(umidHex, bytes + kBEXTUMIDOffset, kBEXTUMIDSize);
        }
    }

    // Rewritten only when changed: a stored value read back as a double does not always convert to
    // the same integer.
    if (_version >= 2) {
        const bool upgraded = read.version < 2;
        if (upgraded || _loudnessIntegrated != read.loudnessIntegrated)
            OSWriteLittleInt16(bytes, kBEXTLoudnessValueOffset, (uint16_t)(int16_t)(_loudnessIntegrated * 100));
        if (upgraded || _loudnessRange != read.loudnessRange)
            OSWriteLittleInt16(bytes, kBEXTLoudnessRangeOffset, (uint16_t)(int16_t)(_loudnessRange * 100));
        if (upgraded || _maxTruePeakLevel != read.maxTruePeakLevel)
            OSWriteLittleInt16(bytes, kBEXTMaxTruePeakOffset, (uint16_t)(int16_t)(_maxTruePeakLevel * 100));
        if (upgraded || _maxMomentaryLoudness != read.maxMomentaryLoudness)
            OSWriteLittleInt16(bytes, kBEXTMaxMomentaryOffset, (uint16_t)(int16_t)(_maxMomentaryLoudness * 100));
        if (upgraded || _maxShortTermLoudness != read.maxShortTermLoudness)
            OSWriteLittleInt16(bytes, kBEXTMaxShortTermOffset, (uint16_t)(int16_t)(_maxShortTermLoudness * 100));
    }

    return [buffer copy];
}

@end
