// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#import "AudioMarker.h"
#import <Foundation/Foundation.h>

@implementation AudioMarker
- (nonnull id)initWithName:(nonnull NSString *)name
                      time:(NSTimeInterval)time
                sampleRate:(Float64)sampleRate
                  markerID:(SInt32)markerID {
    self = [super init];

    _name = name;
    _time = time;
    _sampleRate = sampleRate;
    _markerID = markerID;

    return self;
}

- (Float64)framePosition {
    return _time * _sampleRate;
}

@end
