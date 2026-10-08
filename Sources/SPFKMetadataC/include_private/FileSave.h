// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef FILESAVE_H
#define FILESAVE_H

#include <taglib/tfile.h>

namespace FileSave {

/// Saves `file` without moving its audio where the container allows it: a WAV through
/// `WaveChunkPlanner`, anything else through its own `save()`.
bool save(TagLib::File *file);

} // namespace FileSave

#endif /* FILESAVE_H */
