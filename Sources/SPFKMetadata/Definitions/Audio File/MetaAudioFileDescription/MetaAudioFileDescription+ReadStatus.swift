// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataBase
internal import SPFKMetadataC

extension MetaAudioFileDescription {
    /// The reads `init(parsing:)` makes for each component that can fail apart from the rest. A
    /// WAV's are one open, which the parse needs whole, so none of them is here.
    struct ParseReads: Sendable {
        var tags: @Sendable (URL) throws -> TagProperties = { try TagProperties(url: $0) }

        var markers: @Sendable (URL, AudioFileType?) async throws -> AudioMarkerDescriptionCollection = {
            try await AudioMarkerDescriptionCollection(url: $0, fileType: $1)
        }

        /// A FLAC's BEXT and iXML blocks; false when the file can't be read.
        var flacChunks: @Sendable (FlacFileC) -> Bool = { $0.load() }
    }
}
