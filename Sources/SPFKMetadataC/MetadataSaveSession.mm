// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <cstring>
#import <memory>
#import <vector>

#import <fcntl.h>
#import <sys/mount.h>
#import <sys/stat.h>
#import <unistd.h>

#import <taglib/aifffile.h>
#import <taglib/fileref.h>
#import <taglib/tdeferredwritestream.h>
#import <taglib/tfilestream.h>

#import "MetadataSaveSession.h"
#import "AIFFMarkerChunks.h"
#import "FileSave.h"

using namespace TagLib;

/// File systems where a swap keeps the creation date, Finder tags, extended attributes and ACLs
/// (measured); network volumes are not among them.
static bool canSwapOn(const char *fileSystem) {
    for (const char *name : { "apfs", "hfs", "exfat", "msdos" }) {
        if (strcmp(fileSystem, name) == 0)
            return true;
    }
    return false;
}

@implementation MetadataSaveSession {
    // Each stream outlives what reads through it: the FileRef reads the deferred stream, which
    // reads the file.
    std::unique_ptr<FileStream> _stream;
    std::unique_ptr<DeferredWriteStream> _deferred;
    std::unique_ptr<FileRef> _fileRef;
    std::vector<IFFChunkPlanner::Edit> _chunkEdits;
    NSString *_path;
}

- (nullable instancetype)initWithPath:(NSString *)path {
    self = [super init];
    _path = [path copy];

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

    // A failed save leaves the file as it was rather than half written. A save that moves most of
    // the file -- the audio -- is written to a new file swapped in whole, so an interrupted move
    // cannot break it; a smaller move stays in place, where the swap would cost a full copy.
    if (saved) {
        const bool movesMost = _deferred->bytesToMove() * 2 >= _deferred->length();
        saved = (movesMost && [self replaceWithSavedContent]) || _deferred->commit();
    }

    // Closing flushes the stream's buffered writes, so the next writer to open the file sees them.
    _fileRef.reset();
    _deferred.reset();
    _stream.reset();
    return saved;
}

/// Writes the saved content to a sibling file and swaps it in. False, with the file untouched,
/// when the swap would lose something: another hard link keeps the old content, the folder must be
/// writable with room for a second copy, and only the file systems in `canSwapOn` are known to carry
/// the file's attributes across the swap.
- (bool)replaceWithSavedContent {
    NSURL *url = [NSURL fileURLWithPath:_path];
    NSURL *directory = url.URLByDeletingLastPathComponent;

    struct stat info;
    if (stat(url.fileSystemRepresentation, &info) != 0 || info.st_nlink != 1)
        return false;

    if (access(directory.fileSystemRepresentation, W_OK) != 0)
        return false;

    struct statfs volume;
    const unsigned long long needed = static_cast<unsigned long long>(_deferred->length()) + (1 << 20);
    if (statfs(directory.fileSystemRepresentation, &volume) != 0 || !canSwapOn(volume.f_fstypename) ||
        static_cast<unsigned long long>(volume.f_bavail) * volume.f_bsize < needed)
        return false;

    NSString *name = [NSString stringWithFormat:@".%@.%@.save", url.lastPathComponent, NSUUID.UUID.UUIDString];
    NSURL *temporary = [directory URLByAppendingPathComponent:name];
    NSFileManager *fileManager = NSFileManager.defaultManager;

    if (![fileManager createFileAtPath:temporary.path contents:nil attributes:nil])
        return false;

    bool written;
    {
        FileStream stream(temporary.fileSystemRepresentation);
        written = stream.isOpen() && !stream.readOnly() && _deferred->writeTo(&stream);
    }

    // On disk before the swap, so a power loss cannot leave the name on unwritten content.
    if (written) {
        const int descriptor = open(temporary.fileSystemRepresentation, O_RDWR);
        written = descriptor >= 0 && fcntl(descriptor, F_FULLFSYNC) == 0;
        if (descriptor >= 0)
            close(descriptor);
    }

    if (!written || ![fileManager replaceItemAtURL:url withItemAtURL:temporary backupItemName:nil options:0 resultingItemURL:nil error:nil]) {
        [fileManager removeItemAtURL:temporary error:nil];
        return false;
    }

    return true;
}

@end
