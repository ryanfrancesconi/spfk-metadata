// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import "WaveMarkerChunks.h"

using namespace TagLib;

namespace {

const unsigned short formatPCM = 0x0001;
const unsigned short formatFloat = 0x0003;
const unsigned short formatExtensible = 0xFFFE;

/// `KSDATAFORMAT_SUBTYPE_*`'s bytes after the format tag.
const ByteVector subformatGUIDTail("\x00\x00\x00\x00\x10\x00\x80\x00\x00\xAA\x00\x38\x9B\x71", 14);

/// PCM or float, read through an extensible header's subformat. 0 for anything else.
unsigned short sampleFormat(const ByteVector &fmt) {
    const unsigned short tag = fmt.toUShort(0, false);

    if (tag != formatExtensible)
        return tag == formatPCM || tag == formatFloat ? tag : 0;

    if (fmt.size() < 40 || fmt.toUShort(16, false) < 22 || fmt.mid(26, 14) != subformatGUIDTail)
        return 0;

    const unsigned short subformat = fmt.toUShort(24, false);
    return subformat == formatPCM || subformat == formatFloat ? subformat : 0;
}

} // namespace

long long WaveMarkerFile::pcmFrameCount() {
    int fmtIndex = -1;
    int dataIndex = -1;

    // Core Audio reads the last of each, TagLib the first.
    for (unsigned int i = 0; i < chunkCount(); i++) {
        const ByteVector name = chunkName(i);
        int *index = name == "fmt " ? &fmtIndex : name == "data" ? &dataIndex : nullptr;

        if (!index)
            continue;
        if (*index >= 0)
            return -1;

        *index = static_cast<int>(i);
    }

    if (fmtIndex < 0 || dataIndex < 0)
        return -1;

    const ByteVector fmt = chunkData(fmtIndex);
    if (fmt.size() < 16 || sampleFormat(fmt) == 0)
        return -1;

    const unsigned int channels = fmt.toUShort(2, false);
    const unsigned int sampleRate = fmt.toUInt(4, false);
    const unsigned int blockAlign = fmt.toUShort(12, false);
    const unsigned int bitsPerSample = fmt.toUShort(14, false);

    if (channels == 0 || sampleRate == 0 || bitsPerSample == 0 || blockAlign != channels * ((bitsPerSample + 7) / 8))
        return -1;

    seek(0);
    const ByteVector header = readBlock(12);
    if (header.size() < 12)
        return -1;

    const bool longForm = header.startsWith("RF64") || header.startsWith("BW64");
    unsigned long long formSize = header.toUInt(4, false);

    seek(chunkOffset(dataIndex) - 4);
    unsigned long long declaredDataSize = readBlock(4).toUInt(0, false);

    if (longForm) {
        if (formSize != 0xFFFFFFFFu || chunkCount() == 0 || chunkName(0) != "ds64")
            return -1;

        const ByteVector ds64 = chunkData(0);
        if (ds64.size() < 28)
            return -1;

        formSize = ds64.toULongLong(0, false);
        if (declaredDataSize == 0xFFFFFFFFu)
            declaredDataSize = ds64.toULongLong(8, false);
    }

    const offset_t dataSize = chunkDataSize64(dataIndex);

    if (formSize != static_cast<unsigned long long>(length() - 8) || declaredDataSize != static_cast<unsigned long long>(dataSize))
        return -1;

    return dataSize / blockAlign;
}
