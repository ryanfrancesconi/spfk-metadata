// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagRatingFile_H
#define TagRatingFile_H

#import <Foundation/Foundation.h>

namespace TagLib {
class File;
}

/// For callers that already hold the file open. Stars, or -1 when nothing is stored.
int TagRatingReadFromFile(TagLib::File *f);

/// 0 clears the rating. A container with no branch here is left untouched.
void TagRatingWriteToFile(TagLib::File *f, int stars);

/// The dictionary's `RATING` as stars; 0 when absent or out of range, so a save clears it.
int TagRatingStarsInDictionary(NSDictionary *dictionary);

#endif
