// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef StringUtil_H
#define StringUtil_H

#import <Foundation/Foundation.h>
#import <iostream>
#import <taglib/tstring.h>

namespace StringUtil {
/**
   If the length of the string is less than n characters, add null byte.
   returns the size written.
   - Parameters:
   - dest: destination
   - src: source
   - n: max length of field
 */
static size_t strncpy_validate(char *dest, const char *src, size_t n) {
    // reserve space for null
    size_t length = strlen(src) + 1;

    if (length >= n) {
        // truncate to exactly n
        strncpy(dest, src, n);
        return n;
        //
    } else {
        strncpy(dest, src, length);

        // if less than n, add null termination
        dest[length - 1] = '\0';
        return length;
    }
}

/**
   If a string is < n, pad with character 0 -- for UMID bext spec which
   says to fill the remaining size with 0s.
 */
static void strncpy_pad0(char *dest, const char *src, size_t n, bool terminate) {
    size_t length = strlen(src);

    if (length < n) {
        strncpy(dest, src, length);

        for (size_t i = length; i < n; i++) {
            dest[i] = '0'; // character 0, not termination
        }

        if (terminate) {
            dest[n - 1] = '\0';
            assert(strlen(dest) == n - 1);
        }
    } else {
        strncpy(dest, src, n);
    }
}

/// Converts a hex character ('0'-'9', 'A'-'F', 'a'-'f') to its numeric value.
/// Returns -1 for invalid characters.
static int hexCharToNibble(char c) {
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    return -1;
}

/// Decodes a hex string into raw bytes. Each pair of hex characters becomes one byte.
/// @param hex The hex string (e.g. "53504F4E"). Length should be even.
/// @param dest Destination buffer for decoded bytes.
/// @param maxBytes Maximum number of bytes to write.
/// @return Number of bytes written.
static size_t hexToBytes(const char *hex, uint8_t *dest, size_t maxBytes) {
    size_t hexLen = strlen(hex);
    size_t byteCount = MIN(hexLen / 2, maxBytes);

    for (size_t i = 0; i < byteCount; i++) {
        int hi = hexCharToNibble(hex[i * 2]);
        int lo = hexCharToNibble(hex[i * 2 + 1]);

        if (hi < 0 || lo < 0) {
            dest[i] = 0;
        } else {
            dest[i] = (uint8_t)((hi << 4) | lo);
        }
    }

    return byteCount;
}

static std::string charToHexString(unsigned char c) {
    static const std::array<char, 16> hex_chars = {'0', '1', '2', '3', '4', '5', '6', '7',
                                                   '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
    std::string result;

    result += hex_chars[(c >> 4) & 0xF]; // High nibble
    result += hex_chars[c & 0xF];        // Low nibble
    return result;
}

/**
   A string is null terminated in the bext chunk if it is less than the full size,
   otherwise it isn't. This will clamp to maxLength to make sure it doesn't keep
   reading towards the next null byte which would overflow into a subsequent
   field in the bext data.
 */
// BWF spec says ASCII, but real-world files often contain UTF-8 or Latin-1 content.
// Try UTF-8 first (a superset of ASCII), fall back to Latin-1 so high bytes aren't lost.
static NSString *asciiString(const char *s, size_t maxLength) {
    size_t len = strnlen(s, maxLength);
    NSString *result = [[NSString alloc] initWithBytes:s length:len encoding:NSUTF8StringEncoding];
    if (!result) {
        result = [[NSString alloc] initWithBytes:s length:len encoding:NSISOLatin1StringEncoding];
    }
    return result ?: @"";
}

static NSString *utf8NSString(TagLib::String string) {
    return [[NSString alloc] initWithCString:string.toCString(true) encoding:NSUTF8StringEncoding];
}

static NSString *utf8NSString(std::string string) {
    return [[NSString alloc] initWithCString:string.c_str() encoding:NSUTF8StringEncoding];
}

static const char *asciiCString(NSString *string) { return [string cStringUsingEncoding:NSASCIIStringEncoding]; }

static const char *utf8CString(NSString *string) { return [string cStringUsingEncoding:NSUTF8StringEncoding]; }
} // namespace StringUtil

#endif // !StringUtil_H
