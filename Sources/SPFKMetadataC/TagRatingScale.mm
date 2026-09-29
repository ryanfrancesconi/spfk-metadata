// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#import "TagRating.h"
#import "TagRatingScale.h"

namespace TagRatingScale {
int starsFromNormalized(int n) { return n / 20; }
int normalizedFromStars(int stars) { return stars * 20; }

int starsFromStoredValue(int v) {
    if (v > TagRatingMinStars && v <= TagRatingMaxStars)
        return v;
    if (v > TagRatingMaxStars && v <= normalizedFromStars(TagRatingMaxStars))
        return starsFromNormalized(v);
    return -1;
}

// The de-facto POPM ranges used by WMP, MediaMonkey and most DJ software.
int starsFromPopmByte(int b) {
    if (b <= 0)
        return 0;
    if (b <= 54)
        return 1;
    if (b <= 117)
        return 2;
    if (b <= 159)
        return 3;
    if (b <= 223)
        return 4;
    return 5;
}

// Windows Media Player's canonical values.
int popmByteFromStars(int stars) {
    switch (stars) {
    case 1:
        return 1;
    case 2:
        return 64;
    case 3:
        return 128;
    case 4:
        return 196;
    case 5:
        return 255;
    default:
        return 0;
    }
}

unsigned int asfFromStars(int stars) {
    switch (stars) {
    case 1:
        return 1;
    case 2:
        return 25;
    case 3:
        return 50;
    case 4:
        return 75;
    case 5:
        return 99;
    default:
        return 0;
    }
}

int starsFromAsf(int v) {
    if (v <= 0)
        return 0;
    if (v < 13)
        return 1;
    if (v < 38)
        return 2;
    if (v < 63)
        return 3;
    if (v < 88)
        return 4;
    return 5;
}

std::string fmpsRatingString(int normalized) {
    int whole = normalized / 100;
    int frac3 = (normalized % 100) * 10;
    char buf[16];
    snprintf(buf, sizeof(buf), "%d.%03d", whole, frac3);
    return std::string(buf);
}

int parseFmpsRating(const std::string &s) {
    size_t dot = s.find('.');
    if (dot == std::string::npos)
        return -1;

    int whole = 0;
    for (size_t i = 0; i < dot; i++) {
        if (s[i] < '0' || s[i] > '9')
            return -1;
        whole = whole * 10 + (s[i] - '0');
    }

    // Up to three fractional digits, right-padded: "8", "80" and "800" all mean 0.800.
    int frac = 0, digits = 0;
    for (size_t i = dot + 1; i < s.size() && digits < 3; i++, digits++) {
        if (s[i] < '0' || s[i] > '9')
            return -1;
        frac = frac * 10 + (s[i] - '0');
    }
    while (digits < 3) {
        frac *= 10;
        digits++;
    }

    int normalized = whole * 100 + frac / 10;
    if (normalized < 0 || normalized > 100)
        return -1;
    return normalized;
}
} // namespace TagRatingScale
