// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef FILESAVE_H
#define FILESAVE_H

#include <taglib/id3v2.h>
#include <taglib/id3v2tag.h>
#include <taglib/tfile.h>

namespace FileSave {

/// Saves `file` without moving its audio where the container allows it: a WAV or AIFF through
/// `IFFChunkPlanner`, Matroska with `WriteStyle::AvoidInsert`, an MP3 keeping its ID3 version and
/// adding no tag it lacked, anything else through its own `save()`.
bool save(TagLib::File *file);

/// The version `tag` was read as when that is v2.3 and v2.3 can hold every frame it has; v2.4
/// otherwise, and for a new tag.
TagLib::ID3v2::Version id3Version(TagLib::ID3v2::Tag *tag);

} // namespace FileSave

#endif /* FILESAVE_H */
