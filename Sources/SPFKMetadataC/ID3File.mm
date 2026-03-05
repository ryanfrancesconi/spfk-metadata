// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <Foundation/Foundation.h>
#import <iostream>

#import <taglib/id3v2tag.h>
#import <taglib/privateframe.h>
#import <taglib/textidentificationframe.h>
#import <taglib/wavfile.h>

#import "ID3File.h"
#import "TagFile.h"
#import "TagFileType.h"
#import "TagUtil.h"

@implementation ID3File

using namespace std;
using namespace TagLib;

- (instancetype)initWithPath:(nonnull NSString *)path {
    self = [super init];

    _path = path;
    _fileType = [TagFileType detectType:path];
    _dictionary = [[NSMutableDictionary alloc] init];

    return self;
}

- (bool)load {
    _dictionary = TagUtil::parseID3ToDictionary(_path, _fileType);
    return _dictionary.count > 0;
}

- (bool)save {
    return [TagFile write:_dictionary path:_path];
}

@end
