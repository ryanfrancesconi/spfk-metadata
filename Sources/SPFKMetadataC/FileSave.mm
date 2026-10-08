// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <taglib/matroskafile.h>
#import <taglib/wavfile.h>

#import "FileSave.h"
#import "IFFChunkPlanner.h"

using namespace TagLib;

namespace FileSave {

bool save(File *file) {
    if (auto *wav = dynamic_cast<RIFF::WAV::File *>(file))
        return IFFChunkPlanner::save(*wav);

    // A grown element ahead of the last cluster is voided and appended instead of moving the clusters.
    if (auto *matroska = dynamic_cast<Matroska::File *>(file))
        return matroska->save(Matroska::WriteStyle::AvoidInsert);

    return file->save();
}

} // namespace FileSave
