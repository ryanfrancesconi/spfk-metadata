import Foundation
import SPFKMetadataBase
import SPFKMetadataC

/// Adds `CaseIterable` conformance to the C-defined `TagFileTypeDef` constants for Swift enumeration.
extension TagFileTypeDef: @retroactive CaseIterable {
    /// All TagLib-supported file type definitions.
    public static var allCases: [TagFileTypeDef] {
        [
            .aac,
            .aiff,
            .flac,
            .m4a,
            .mp3,
            .mp4,
            .opus,
            .vorbis,
            .wave,
        ]
    }
}
