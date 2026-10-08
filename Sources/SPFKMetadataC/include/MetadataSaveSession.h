// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One TagLib open of a file for a save: each writer's `toFile:`/`toFileRef:` method changes it in
/// memory, and `save` writes them all at once.
@interface MetadataSaveSession : NSObject

/// The `TagLib::FileRef *`, for the writers' `toFileRef:` methods.
@property(nonatomic, readonly) void *fileRef;

/// The `TagLib::File *`, for the writers' `toFile:` methods.
@property(nonatomic, readonly) void *file;

/// Nil when TagLib cannot open the file for writing.
- (nullable instancetype)initWithPath:(NSString *)path;

- (bool)save;

@end

NS_ASSUME_NONNULL_END
