// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import <taglib/aifffile.h>
#import <taglib/id3v2header.h>
#import <taglib/id3v2tag.h>
#import <taglib/matroskafile.h>
#import <taglib/mpegfile.h>
#import <taglib/wavfile.h>

#import "FileSave.h"
#import "IFFChunkPlanner.h"

using namespace TagLib;

namespace {

/// Whether rendering `tag` as ID3v2.3 would drop a frame: TagLib's downgrade discards these, as
/// its `ID3v2::Tag::downgradeFrames` lists them.
bool holdsFrameV23Drops(ID3v2::Tag *tag) {
    for (const char *frameID : { "ASPI", "EQU2", "RVA2", "SEEK", "SIGN", "TDRL", "TDTG", "TMOO", "TPRO", "TSST" }) {
        if (!tag->frameList(frameID).isEmpty())
            return true;
    }
    return false;
}

} // namespace

namespace FileSave {

ID3v2::Version id3Version(ID3v2::Tag *tag) {
    return tag->header()->majorVersion() == 3 && !holdsFrameV23Drops(tag) ? ID3v2::v3 : ID3v2::v4;
}

bool save(File *file) {
    if (auto *wav = dynamic_cast<RIFF::WAV::File *>(file))
        return IFFChunkPlanner::save(*wav);

    if (auto *aiff = dynamic_cast<RIFF::AIFF::File *>(file))
        return IFFChunkPlanner::save(*aiff);

    // The ID3v2 version the file has, v2.4 for a new tag or one holding a frame v2.3 would drop,
    // and no ID3v1 or stripped APE tag it didn't have: `save()` alone writes v2.4, copies the tag
    // into a new ID3v1 and strips the rest.
    if (auto *mpeg = dynamic_cast<MPEG::File *>(file)) {
        // TagLib keeps an empty ID3v1 tag in memory for every file, and a property save fills it.
        const int tags = MPEG::File::ID3v2 | (mpeg->hasID3v1Tag() ? MPEG::File::ID3v1 : 0) | (mpeg->hasAPETag() ? MPEG::File::APE : 0);
        return mpeg->save(tags, File::StripNone, mpeg->hasID3v2Tag() ? id3Version(mpeg->ID3v2Tag()) : ID3v2::v4, File::DoNotDuplicate);
    }

    // A grown element ahead of the last cluster is voided and appended instead of moving the clusters.
    if (auto *matroska = dynamic_cast<Matroska::File *>(file))
        return matroska->save(Matroska::WriteStyle::AvoidInsert);

    return file->save();
}

} // namespace FileSave
