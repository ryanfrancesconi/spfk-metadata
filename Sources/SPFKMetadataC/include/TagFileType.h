
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Imported into Swift as `TagFileTypeDef` constants (`.wave`).
typedef NSString *const TagFileTypeDef NS_TYPED_ENUM;

extern TagFileTypeDef kTagFileTypeAac;
extern TagFileTypeDef kTagFileTypeAiff;
extern TagFileTypeDef kTagFileTypeFlac;
extern TagFileTypeDef kTagFileTypeM4a;
extern TagFileTypeDef kTagFileTypeMatroska;
extern TagFileTypeDef kTagFileTypeMp3;
extern TagFileTypeDef kTagFileTypeMp4;
extern TagFileTypeDef kTagFileTypeOpus;
extern TagFileTypeDef kTagFileTypeVorbis;
extern TagFileTypeDef kTagFileTypeWave;
extern TagFileTypeDef kTagFileTypeWebm;

@interface TagFileType : NSObject

/// The lowercased extension (`wave`/`bwf` → wav, any `aif*` → aif), returned whether TagLib knows it
/// or not. Only an extensionless file is sniffed, and only that case returns nil.
+ (nullable TagFileTypeDef)detectType:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
