// Copyright Ryan Francesconi. All Rights Reserved. Revision History at
// https://github.com/ryanfrancesconi/spfk-metadata

#import <AudioToolbox/AudioToolbox.h>

#import "AudioMarker.h"
#import "AudioMarkerUtil.h"

@implementation AudioMarkerUtil

#pragma mark - GET

/// Get all markers in this file and return an array of `AudioMarker`
/// @param url URL to parse
+ (NSArray *)getMarkers:(NSURL *)url {
    AudioFileID fileID;
    CFURLRef cfurl = CFBridgingRetain(url);

    if (noErr !=
        AudioFileOpenURL(cfurl, kAudioFileReadPermission, 0, &fileID)) {
        NSLog(@"AudioMarkerUtil: Failed to open url %@", url);
        CFRelease(cfurl);
        return NULL;
    }

    CFRelease(cfurl);
    UInt32 propertySize;
    UInt32 writable;

    if (noErr != AudioFileGetPropertyInfo(fileID, kAudioFilePropertyMarkerList,
                                          &propertySize, &writable)) {
        AudioFileClose(fileID);
        NSLog(@"AudioMarkerUtil: Failed to get AudioFileID for %@", url);
        return NULL;
    }

    if (propertySize <= 0) {
        AudioFileClose(fileID);
        NSLog(@"kAudioFilePropertyMarkerList is invalid %@", url);
        return NULL;
    }

    AudioFileMarkerList *markerList = malloc(propertySize);

    if (noErr != AudioFileGetProperty(fileID, kAudioFilePropertyMarkerList,
                                      &propertySize, markerList)) {
        free(markerList);
        AudioFileClose(fileID);
        NSLog(@"AudioMarkerUtil: Failed to get kAudioFilePropertyMarkerList "
              @"for %@",
              url);
        return NULL;
    }

    UInt32 count = markerList->mNumberMarkers;

    if (count <= 0) {
        AudioFileClose(fileID);
        free(markerList);
        return NULL;
    }

    AudioStreamBasicDescription format;
    UInt32 dataFormatSize = sizeof(format);

    if (noErr != AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat,
                                      &dataFormatSize, &format)) {
        free(markerList);
        AudioFileClose(fileID);
        NSLog(@"AudioMarkerUtil: Failed to get kAudioFilePropertyDataFormat "
              @"for %@",
              url);
        return NULL;
    }

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    int i;

    for (i = 0; i < count; i++) {
        AudioMarker *safm = [[AudioMarker alloc] init];

        safm.markerID = markerList->mMarkers[i].mMarkerID;
        safm.type = markerList->mMarkers[i].mType;
        safm.time = markerList->mMarkers[i].mFramePosition / format.mSampleRate;
        safm.sampleRate = format.mSampleRate;

        if (markerList->mMarkers[i].mName != NULL) {
            safm.name = (__bridge NSString *)markerList->mMarkers[i].mName;
            CFRelease(markerList->mMarkers[i].mName);
        } else {
            // create a default value in the case of missing names
            safm.name = [NSString stringWithFormat:@"Marker %d", i + 1];
        }

        [array addObject:safm];
    }

    free(markerList);
    AudioFileClose(fileID);

    // cast to immutable
    return [array copy];
}

#pragma mark - SET

/// Set an array of RIFF markers in the file
/// @param url `URL` to set markers in
/// @param markerArray `[AudioMarker]`
+ (BOOL)update:(NSURL *)url markers:(NSArray *)markers {
    AudioFileID fileID;
    CFURLRef cfurl = CFBridgingRetain(url);

    if (noErr !=
        AudioFileOpenURL(cfurl, kAudioFileReadWritePermission, 0, &fileID)) {
        NSLog(@"AudioMarkerUtil: Failed to open url %@", url);
        CFRelease(cfurl);
        return false;
    }

    CFRelease(cfurl);

    size_t inNumMarkers = (size_t)markers.count;
    UInt32 propertySize = (UInt32)NumAudioFileMarkersToNumBytes(inNumMarkers);

    if (propertySize <= 0) {
        AudioFileClose(fileID);
        NSLog(@"NumAudioFileMarkersToNumBytes is invalid %@", url);
        return false;
    }

    AudioFileMarkerList *markerList = malloc(propertySize);

    for (int i = 0; i < inNumMarkers; i++) {
        AudioMarker *safm = (AudioMarker *)[markers objectAtIndex:i];

        AudioFileMarker afm = {};
        afm.mName = (__bridge CFStringRef)safm.name;
        afm.mFramePosition = safm.time * safm.sampleRate;
        afm.mMarkerID = i;
        afm.mType = safm.type;
        afm.mSMPTETime = safm.timecode;

        NSLog(@"Adding marker: %@ %f %d %d\n", afm.mName, afm.mFramePosition,
              afm.mMarkerID, afm.mType);

        markerList->mMarkers[i] = afm;
    }

    markerList->mNumberMarkers = (UInt32)inNumMarkers;

    if (noErr != AudioFileSetProperty(fileID, kAudioFilePropertyMarkerList,
                                      propertySize, markerList)) {
        NSLog(@"AudioMarkerUtil: Failed to set kAudioFilePropertyMarkerList "
              @"for %@",
              url);
    }

    free(markerList);
    AudioFileClose(fileID);

    return true;
}

#pragma mark - REMOVE

+ (BOOL)removeAllMarkers:(NSURL *)url {
    AudioFileID fileID;
    CFURLRef cfurl = CFBridgingRetain(url);

    if (noErr !=
        AudioFileOpenURL(cfurl, kAudioFileReadWritePermission, 0, &fileID)) {
        NSLog(@"AudioMarkerUtil: Failed to open url %@", url);
        CFRelease(cfurl);
        return false;
    }

    CFRelease(cfurl);

    UInt32 propertySize = (UInt32)NumAudioFileMarkersToNumBytes(0);
    AudioFileMarkerList *markerList = malloc(propertySize);
    markerList->mNumberMarkers = 0;

    if (noErr != AudioFileSetProperty(fileID, kAudioFilePropertyMarkerList,
                                      propertySize, markerList)) {
        NSLog(
            @"AudioFileStreamSetProperty kAudioFilePropertyMarkerList failed");
        free(markerList);
        AudioFileClose(fileID);
        return false;
    }

    free(markerList);
    AudioFileClose(fileID);
    return true;
}

#pragma mark - COPY

+ (BOOL)copyMarkers:(NSURL *)inputURL to:(NSURL *)destination {
    NSArray *markers = [AudioMarkerUtil getMarkers:inputURL];

    if (markers.count > 0) {
        return [AudioMarkerUtil update:destination markers:markers];
    }

    return false;
}

@end
