// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <memory>
#import <vector>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/tdeferredwritestream.h>
#import <taglib/tfilestream.h>

#import "MetadataSaveSession.h"
#import "AIFFMarkerChunks.h"
#import "FileSave.h"

using namespace TagLib;

@implementation MetadataSaveSession {
    // Each stream outlives what reads through it: the FileRef reads the deferred stream, which
    // reads the file.
    std::unique_ptr<FileStream> _stream;
    std::unique_ptr<DeferredWriteStream> _deferred;
    std::unique_ptr<FileRef> _fileRef;
    std::vector<IFFChunkPlanner::Edit> _chunkEdits;
}

- (nullable instancetype)initWithPath:(NSString *)path {
    self = [super init];

    _stream = std::make_unique<FileStream>(path.fileSystemRepresentation);
    if (!_stream->isOpen() || _stream->readOnly())
        return nil;

    // Every writer's changes are held until `save`, which moves any audio they displace once.
    _deferred = std::make_unique<DeferredWriteStream>(_stream.get());

    // No audio properties: a save doesn't need them.
    _fileRef = std::make_unique<FileRef>(_deferred.get(), false);
    if (_fileRef->isNull())
        return nil;

    return self;
}

- (void)dealloc {
    _fileRef.reset();
    _deferred.reset();
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

    // A failed save leaves the file as it was rather than half written.
    saved = saved && _deferred->commit();

    // Closing flushes the stream's buffered writes, so the next writer to open the file sees them.
    _fileRef.reset();
    _deferred.reset();
    _stream.reset();
    return saved;
}

@end
