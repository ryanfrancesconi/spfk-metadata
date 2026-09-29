// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagRatingScale_H
#define TagRatingScale_H

#import <string>

/// Conversions between star counts (0–5) and each container's stored rating scale. "Normalized" is
/// stars × 20 (0–100), the scale Xiph, MP4 and APE store.
namespace TagRatingScale {
int starsFromNormalized(int n);
int normalizedFromStars(int stars);

/// A stored value as stars: 1–5 is read as raw stars, 6–100 as normalized. -1 otherwise.
int starsFromStoredValue(int v);

int starsFromPopmByte(int b);
int popmByteFromStars(int stars);

/// ASF `WM/SharedUserRating`, 0–99.
unsigned int asfFromStars(int stars);
int starsFromAsf(int v);

/// FMPS_RATING, "0.000"–"1.000". Integer arithmetic only: `atof` and `%f` follow LC_NUMERIC, so a
/// German locale reads "0.800" as 0 and writes "0,800".
std::string fmpsRatingString(int normalized);

/// Normalized 0–100, or -1 when malformed.
int parseFmpsRating(const std::string &s);
} // namespace TagRatingScale

#endif
