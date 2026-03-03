// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

extension TagKey {
    public init?(taglibKey: String) {
        for item in Self.allCases where item.taglibKey == taglibKey {
            self = item
            return
        }
        return nil
    }

    public init?(displayName: String) {
        for item in Self.allCases where item.displayName == displayName {
            self = item
            return
        }

        return nil
    }

    public init?(id3Frame: ID3FrameKey) {
        for item in Self.allCases where item.id3Frame == id3Frame {
            self = item
            return
        }

        return nil
    }

    public init?(infoFrame: InfoFrameKey) {
        for item in Self.allCases where item.infoFrame == infoFrame || item.infoAlternates.contains(infoFrame) {
            self = item
            return
        }

        return nil
    }
}
