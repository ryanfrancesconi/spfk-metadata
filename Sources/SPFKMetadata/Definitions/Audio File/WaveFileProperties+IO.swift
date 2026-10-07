// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension WaveFileProperties {
    /// The values `MetaAudioFileDescription(parsing:)` records for a WAV, from one open. Nil when
    /// the file can't be opened as WAV.
    public init?(url: URL) {
        let waveFile = WaveFileC(path: url.path)

        guard waveFile.load(), let audioProperties = waveFile.audioPropertiesC else { return nil }

        self.init(
            audioFormat: AudioFormatProperties(cObject: audioProperties),
            bextDescription: waveFile.bextDescription?.validated()
        )
    }
}
