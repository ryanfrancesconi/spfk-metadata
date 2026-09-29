// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TAGFILE_H
#define TAGFILE_H

#import "TagAudioPropertiesC.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Any TagLib format's tags as a dictionary keyed by property name.
@interface TagFile : NSObject

/// Set by `load`.
@property(nullable, nonatomic) TagAudioPropertiesC *audioProperties;

/// `"RATING"` is carried here like any key but stored in each format's own rating frame.
@property(nullable, nonatomic) NSDictionary *dictionary;

@property(nonatomic, strong, nonnull) NSString *path;

- (instancetype)initWithPath:(nonnull NSString *)path;

/// False when the file can't be opened or has no tag.
- (bool)load;

/// Replaces every tag with `dictionary`; artwork is kept.
- (bool)save;

@end

NS_ASSUME_NONNULL_END

#endif /* TAGFILE_H */
