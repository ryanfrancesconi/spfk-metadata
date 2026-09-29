// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#ifndef ID3FILE_H
#define ID3FILE_H

NS_ASSUME_NONNULL_BEGIN

/// Every ID3v2 frame, not just the ones `TagFile`'s property map covers — PRIV (where XMP lives) and
/// TXXX included.
@interface ID3File : NSObject

/// Keyed by frame ID ("TIT2"), a TXXX by its description.
@property(nullable, nonatomic) NSMutableDictionary *dictionary;

@property(nonatomic, strong, nonnull) NSString *path;

- (instancetype)initWithPath:(nonnull NSString *)path;

/// False when there is no ID3v2 tag or it has no frames.
- (bool)load;

/// Writes through `TagFile`.
- (bool)save;

@end

NS_ASSUME_NONNULL_END

#endif /* ID3FILE_H */
