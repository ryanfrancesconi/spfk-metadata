// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef StringUtil_H
#define StringUtil_H

#import <Foundation/Foundation.h>
#import <iostream>
#import <taglib/tstring.h>

namespace StringUtil {
/// Copies at most `n` bytes, null-terminated only when shorter than the field. Returns the count.
static size_t strncpy_validate(char *dest, const char *src, size_t n) {
    size_t length = strlen(src) + 1;

    if (length >= n) {
        strncpy(dest, src, n);
        return n;
    } else {
        strncpy(dest, src, length);
        dest[length - 1] = '\0';
        return length;
    }
}

/// Pads a short value to `n` with the character '0' (not a null), as BEXT's date and time fields expect.
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

/// -1 for a character that is not hex.
static int hexCharToNibble(char c) {
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    return -1;
}

/// Decodes up to `maxBytes` bytes; an invalid pair decodes as 0. Returns the count written.
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

    result += hex_chars[(c >> 4) & 0xF];
    result += hex_chars[c & 0xF];
    return result;
}

/// A BEXT field, null-terminated only when shorter than `maxLength`, so the read is clamped to it.
/// The spec says ASCII; real files carry UTF-8 or Latin-1, so both are tried.
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
