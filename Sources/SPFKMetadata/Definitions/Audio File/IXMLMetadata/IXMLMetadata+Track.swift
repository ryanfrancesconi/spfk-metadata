// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

extension IXMLMetadata {
    /// A TRACK_LIST entry.
    public struct Track: Equatable, Sendable {
        /// 1-based channel index in the file.
        public var channelIndex: String?

        public var interleaveIndex: String?

        /// Track name (e.g., "Boom", "Lav 1").
        public var name: String?

        /// Track function (e.g., "INPUT", "MIX").
        public var function: String?

        public init(
            channelIndex: String? = nil,
            interleaveIndex: String? = nil,
            name: String? = nil,
            function: String? = nil
        ) {
            self.channelIndex = channelIndex
            self.interleaveIndex = interleaveIndex
            self.name = name
            self.function = function
        }
    }
}
