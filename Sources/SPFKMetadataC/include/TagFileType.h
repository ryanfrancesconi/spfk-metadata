
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// String constants identifying audio file formats supported by TagLib.
///
/// Declared as `NS_TYPED_ENUM` so Swift imports them as a `TagFileTypeDef` struct
/// with type-safe constants (e.g., `TagFileTypeDef.wave`).
typedef NSString *const TagFileTypeDef NS_TYPED_ENUM;

extern TagFileTypeDef kTagFileTypeAac;
extern TagFileTypeDef kTagFileTypeAiff;
extern TagFileTypeDef kTagFileTypeFlac;
extern TagFileTypeDef kTagFileTypeM4a;
extern TagFileTypeDef kTagFileTypeMp3;
extern TagFileTypeDef kTagFileTypeMp4;
extern TagFileTypeDef kTagFileTypeOpus;
extern TagFileTypeDef kTagFileTypeVorbis;
extern TagFileTypeDef kTagFileTypeWave;

/// Utility for detecting audio file formats via TagLib header inspection.
@interface TagFileType : NSObject

/// Detects the audio file format from the file at the given path.
///
/// First checks the file extension; if no extension is present, opens the file and
/// inspects the header bytes to determine the format.
/// @param path Absolute path to the audio file.
/// @return A `TagFileTypeDef` constant, or `nil` if the format is not recognized.
+ (nullable TagFileTypeDef)detectType:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
