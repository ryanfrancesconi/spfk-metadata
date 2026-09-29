// Copyright Ryan Francesconi. All Rights Reserved. Revision History at
// https://github.com/ryanfrancesconi/spfk-metadata

#import <AudioToolbox/AudioToolbox.h>

#import "AudioMarker.h"
#import "AudioMarkerUtil.h"
#import "WaveMarkerChunks.h"

/// Logs a failure. The caller closes a file this opens.
static BOOL OpenAudioFile(NSURL *url, AudioFilePermissions permission, AudioFileID *fileID) {
    if (noErr != AudioFileOpenURL((__bridge CFURLRef)url, permission, 0, fileID)) {
        NSLog(@"AudioMarkerUtil: Failed to open url %@", url);
        return false;
    }

    return true;
}

/// Takes ownership of each marker's name.
static NSArray *MarkersFromList(AudioFileID fileID, AudioFileMarkerList *markerList, UInt32 propertySize, NSURL *url) {
    if (noErr != AudioFileGetProperty(fileID, kAudioFilePropertyMarkerList, &propertySize, markerList)) {
        NSLog(@"AudioMarkerUtil: Failed to get kAudioFilePropertyMarkerList for %@", url);
        return NULL;
    }

    UInt32 count = markerList->mNumberMarkers;

    if (count <= 0) {
        return NULL;
    }

    AudioStreamBasicDescription format;
    UInt32 dataFormatSize = sizeof(format);

    if (noErr != AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &dataFormatSize, &format)) {
        NSLog(@"AudioMarkerUtil: Failed to get kAudioFilePropertyDataFormat for %@", url);
        return NULL;
    }

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];

    for (int i = 0; i < count; i++) {
        AudioFileMarker afm = markerList->mMarkers[i];
        AudioMarker *safm = [[AudioMarker alloc] init];

        safm.markerID = afm.mMarkerID;
        safm.type = afm.mType;
        safm.time = afm.mFramePosition / format.mSampleRate;
        safm.sampleRate = format.mSampleRate;

        if (afm.mName != NULL) {
            safm.name = (__bridge NSString *)afm.mName;
            CFRelease(afm.mName);
        } else {
            safm.name = [NSString stringWithFormat:@"Marker %d", i + 1];
        }

        [array addObject:safm];
    }

    return [array copy];
}

static NSArray *ReadMarkers(AudioFileID fileID, NSURL *url) {
    UInt32 propertySize;
    UInt32 writable;

    if (noErr != AudioFileGetPropertyInfo(fileID, kAudioFilePropertyMarkerList, &propertySize, &writable)) {
        NSLog(@"AudioMarkerUtil: Failed to get AudioFileID for %@", url);
        return NULL;
    }

    if (propertySize <= 0) {
        return NULL;
    }

    AudioFileMarkerList *markerList = malloc(propertySize);
    NSArray *markers = MarkersFromList(fileID, markerList, propertySize, url);
    free(markerList);

    return markers;
}

static BOOL WriteMarkers(AudioFileID fileID, NSArray *markers, NSURL *url) {
    // Positions are in the file's frames, so the marker's own sampleRate is not used.
    AudioStreamBasicDescription format;
    UInt32 dataFormatSize = sizeof(format);

    if (noErr != AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &dataFormatSize, &format) ||
        format.mSampleRate <= 0) {
        NSLog(@"AudioMarkerUtil: Failed to get kAudioFilePropertyDataFormat for %@", url);
        return false;
    }

    size_t inNumMarkers = (size_t)markers.count;
    UInt32 propertySize = (UInt32)NumAudioFileMarkersToNumBytes(inNumMarkers);

    if (propertySize <= 0) {
        NSLog(@"NumAudioFileMarkersToNumBytes is invalid %@", url);
        return false;
    }

    AudioFileMarkerList *markerList = malloc(propertySize);

    for (int i = 0; i < inNumMarkers; i++) {
        AudioMarker *safm = (AudioMarker *)[markers objectAtIndex:i];

        AudioFileMarker afm = {};
        afm.mName = (__bridge CFStringRef)safm.name;
        afm.mFramePosition = safm.time * format.mSampleRate;
        afm.mMarkerID = i;
        afm.mType = safm.type;
        afm.mSMPTETime = safm.timecode;

        markerList->mMarkers[i] = afm;
    }

    markerList->mNumberMarkers = (UInt32)inNumMarkers;

    OSStatus status = AudioFileSetProperty(fileID, kAudioFilePropertyMarkerList, propertySize, markerList);
    free(markerList);

    if (noErr != status) {
        NSLog(@"AudioMarkerUtil: Failed to set kAudioFilePropertyMarkerList (%d) for %@", (int)status, url);
        return false;
    }

    return true;
}

static BOOL RemoveMarkers(AudioFileID fileID) {
    UInt32 propertySize = (UInt32)NumAudioFileMarkersToNumBytes(0);
    AudioFileMarkerList *markerList = malloc(propertySize);
    markerList->mNumberMarkers = 0;

    OSStatus status = AudioFileSetProperty(fileID, kAudioFilePropertyMarkerList, propertySize, markerList);
    free(markerList);

    if (noErr != status) {
        NSLog(@"AudioFileStreamSetProperty kAudioFilePropertyMarkerList failed");
        return false;
    }

    return true;
}

@implementation AudioMarkerUtil

+ (NSArray *)read:(NSURL *)url {
    if ([WaveMarkerChunks isRIFFWave:url]) {
        return [WaveMarkerChunks read:url];
    }

    AudioFileID fileID;

    if (!OpenAudioFile(url, kAudioFileReadPermission, &fileID)) {
        return NULL;
    }

    NSArray *markers = ReadMarkers(fileID, url);
    AudioFileClose(fileID);

    return markers;
}

+ (BOOL)write:(NSArray *)markers to:(NSURL *)url {
    if ([WaveMarkerChunks isRIFFWave:url]) {
        return [WaveMarkerChunks write:markers to:url];
    }

    AudioFileID fileID;

    if (!OpenAudioFile(url, kAudioFileReadWritePermission, &fileID)) {
        return false;
    }

    BOOL success = WriteMarkers(fileID, markers, url);
    AudioFileClose(fileID);

    return success;
}

+ (BOOL)remove:(NSURL *)url {
    if ([WaveMarkerChunks isRIFFWave:url]) {
        return [WaveMarkerChunks write:@[] to:url];
    }

    AudioFileID fileID;

    if (!OpenAudioFile(url, kAudioFileReadWritePermission, &fileID)) {
        return false;
    }

    BOOL success = RemoveMarkers(fileID);
    AudioFileClose(fileID);

    return success;
}

#pragma mark - COPY

+ (BOOL)copyMarkers:(NSURL *)inputURL to:(NSURL *)destination {
    NSArray *markers = [AudioMarkerUtil read:inputURL];

    if (markers.count > 0) {
        return [AudioMarkerUtil write:markers to:destination];
    }

    return false;
}

@end
