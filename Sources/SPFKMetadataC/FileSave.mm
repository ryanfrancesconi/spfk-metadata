// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <taglib/wavfile.h>

#import "FileSave.h"
#import "WaveChunkPlanner.h"

using namespace TagLib;

namespace FileSave {

bool save(File *file) {
    if (auto *wav = dynamic_cast<RIFF::WAV::File *>(file))
        return WaveChunkPlanner::save(*wav);

    return file->save();
}

} // namespace FileSave
