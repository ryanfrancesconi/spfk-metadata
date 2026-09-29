// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

#ifndef TagImageDecoding_H
#define TagImageDecoding_H

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// +1 image, or NULL. CGImageSource first; the JPEG and PNG decoders accept some marginal input it
/// rejects.
CGImageRef _Nullable TagCreateImage(NSData *_Nonnull data);

#ifdef __cplusplus
}
#endif

#endif
