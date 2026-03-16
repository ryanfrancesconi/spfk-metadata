// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>

#ifndef ID3FILE_H
#define ID3FILE_H

NS_ASSUME_NONNULL_BEGIN

/// Low-level ID3v2 frame access via TagLib, exposing all frames (not just
/// the standard properties returned by `TagFile`). Use this when you need
/// frame-level control, XMP access, or user-defined (TXXX) frames.
@interface ID3File : NSObject

/// All ID3 frames as key-value pairs, keyed by frame ID (e.g., "TIT2", "TXXX").
@property(nullable, nonatomic) NSMutableDictionary *dictionary;

/// Absolute path to the audio file.
@property(nonatomic, strong, nonnull) NSString *path;

/// The detected TagLib file type string (e.g., "mp3", "wav"), or `nil` if unknown.
@property(nonatomic, strong, nullable) NSString *fileType;

/// Creates an `ID3File` for the audio file at the given path.
/// @param path Absolute path to the audio file.
- (instancetype)initWithPath:(nonnull NSString *)path;

/// Opens the file and reads all ID3 frames into `dictionary`.
/// @return `true` if the file was opened successfully.
- (bool)load;

/// Writes the current `dictionary` contents back as ID3 frames.
/// @return `true` if the save succeeded.
- (bool)save;

@end

NS_ASSUME_NONNULL_END

#endif /* ID3FILE_H */
