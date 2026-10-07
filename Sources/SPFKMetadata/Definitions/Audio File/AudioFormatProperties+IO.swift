// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import Foundation
import SPFKAudioBase
import SPFKMetadataBase
internal import SPFKMetadataC

extension AudioFormatProperties {
    public init(audioFile: AVAudioFile) {
        let bits = audioFile.fileFormat.bitsPerChannel
        self.init(
            channelCount: audioFile.fileFormat.channelCount,
            sampleRate: audioFile.fileFormat.sampleRate,
            bitsPerChannel: bits > 0 ? Int(bits) : nil,
            bitRate: audioFile.dataRate?.int32,
            duration: audioFile.duration
        )
    }

    init(cObject: TagAudioPropertiesC) {
        self.init(
            channelCount: AVAudioChannelCount(cObject.channelCount),
            sampleRate: cObject.sampleRate,
            bitsPerChannel: cObject.bitsPerSample > 0 ? Int(cObject.bitsPerSample) : nil,
            bitRate: cObject.bitRate,
            duration: cObject.duration
        )
    }
}
