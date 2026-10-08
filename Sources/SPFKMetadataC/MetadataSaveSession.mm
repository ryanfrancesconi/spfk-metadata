// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <memory>
#import <vector>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/tfilestream.h>

#import "MetadataSaveSession.h"
#import "AIFFMarkerChunks.h"
#import "FileSave.h"

using namespace TagLib;

@implementation MetadataSaveSession {
    // The stream outlives the FileRef, which reads through it and does not own it.
    std::unique_ptr<FileStream> _stream;
    std::unique_ptr<FileRef> _fileRef;
    std::vector<IFFChunkPlanner::Edit> _chunkEdits;
}

- (nullable instancetype)initWithPath:(NSString *)path {
    self = [super init];

    _stream = std::make_unique<FileStream>(path.fileSystemRepresentation);
    if (!_stream->isOpen() || _stream->readOnly())
        return nil;

    // Audio moved by a metadata block growing ahead of it goes through this buffer.
    _stream->setMoveBufferSize(1 << 20);

    // No audio properties: a save doesn't need them.
    _fileRef = std::make_unique<FileRef>(_stream.get(), false);
    if (_fileRef->isNull())
        return nil;

    return self;
}

- (void)dealloc {
    _fileRef.reset();
    _stream.reset();
}

- (void *)fileRef {
    return _fileRef.get();
}

- (void *)file {
    return _fileRef->file();
}

- (void)setAIFFMarkers:(NSArray *)markers sampleRate:(double)sampleRate {
    _chunkEdits.push_back(AIFFMarkers::edit(markers, sampleRate));
}

- (bool)save {
    if (!_fileRef)
        return false;

    bool saved;
    if (auto *aiff = dynamic_cast<RIFF::AIFF::File *>(_fileRef->file()); aiff && !_chunkEdits.empty())
        saved = IFFChunkPlanner::save(*aiff, _chunkEdits);
    else
        saved = FileSave::save(_fileRef->file());

    // Closing flushes the stream's buffered writes, so the next writer to open the file sees them.
    _fileRef.reset();
    _stream.reset();
    return saved;
}

@end
