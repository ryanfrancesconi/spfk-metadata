// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-audio

import AVFoundation
import Foundation
import SPFKAudioBase

/// Audio stream format properties (channel count, sample rate, bit depth, bit rate, duration)
/// with pre-formatted human-readable description strings for UI display.
public struct AudioFormatProperties: Hashable, Sendable {
    /// Number of audio channels (1 = Mono, 2 = Stereo, etc.).
    public private(set) var channelCount: AVAudioChannelCount

    /// Sample rate in Hz (e.g., 44100, 48000).
    public private(set) var sampleRate: Double

    /// Bit depth per channel, if available (e.g., 16, 24, 32). `nil` for compressed formats.
    public private(set) var bitsPerChannel: Int?

    /// Bit rate in kbit/s for compressed formats (e.g., 320 for MP3). `nil` for uncompressed.
    public private(set) var bitRate: Int32?

    /// Duration of the audio file in seconds.
    public private(set) var duration: TimeInterval = 0

    // MARK: cached descriptions

    /// Pre-formatted duration string (e.g., "3:42.150").
    public private(set) var durationDescription: String = ""

    /// Combined format summary (e.g., "48 kHz, 24 bit, Stereo").
    public private(set) var formatDescription: String = ""

    /// Channel layout label (e.g., "Mono", "Stereo", "6 Channel").
    public private(set) var channelsDescription: String = ""

    /// Bit rate label (e.g., "320 kbit/s"). Empty for uncompressed formats.
    public private(set) var bitRateDescription: String = ""

    public init(
        channelCount: AVAudioChannelCount,
        sampleRate: Double,
        bitsPerChannel: Int? = nil,
        bitRate: Int32? = nil,
        duration: TimeInterval
    ) {
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.bitsPerChannel = bitsPerChannel
        self.bitRate = bitRate
        self.duration = duration

        initialize()
    }

    /// Updates the bit rate and regenerates the cached description strings.
    public mutating func update(bitRate: Int32) {
        self.bitRate = bitRate
        updateBitRateDescription()
        updateFormatDescription()
    }

    private mutating func initialize() {
        updateChannelsDescription()
        updateBitRateDescription()
        updateFormatDescription()
        updateDurationDescription()
    }

    private mutating func updateChannelsDescription() {
        guard channelCount > 0 else {
            channelsDescription = ""
            return
        }

        var out = "Stereo"

        if channelCount == 1 {
            out = "Mono"

        } else if channelCount > 2 {
            out = "\(channelCount) Channel"
        }

        channelsDescription = out
    }

    private mutating func updateBitRateDescription() {
        guard let bitRate, bitRate > 0 else {
            bitRateDescription = ""
            return
        }

        bitRateDescription = "\(bitRate) kbit/s"
    }

    private mutating func updateFormatDescription() {
        let kHz = (sampleRate / 1000).truncated(decimalPlaces: 1)
        var kHzString = kHz.string

        if kHz.truncatingRemainder(dividingBy: 1) == 0 {
            kHzString = kHz.int.string
        }

        var out = "\(kHzString) kHz"

        if let bitsPerChannel {
            out += bitsPerChannel > 0 ? ", \(bitsPerChannel) bit" : ""
        }

        if bitRate != nil, !bitRateDescription.isEmpty {
            out += ", \(bitRateDescription)"
        }

        if channelsDescription != "" {
            out += ", \(channelsDescription)"
        }

        formatDescription = out
    }

    private mutating func updateDurationDescription() {
        durationDescription = RealTimeDomain.string(
            seconds: duration,
            showHours: .auto,
            showMilliseconds: true
        )
    }
}

extension AudioFormatProperties: Codable {
    enum CodingKeys: String, CodingKey {
        case channelCount
        case sampleRate
        case bitsPerChannel
        case bitRate
        case duration
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channelCount = try container.decode(AVAudioChannelCount.self, forKey: .channelCount)
        sampleRate = try container.decode(Double.self, forKey: .sampleRate)
        bitsPerChannel = try? container.decodeIfPresent(Int.self, forKey: .bitsPerChannel)
        bitRate = try? container.decodeIfPresent(Int32.self, forKey: .bitRate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)

        initialize()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(channelCount, forKey: .channelCount)
        try container.encode(sampleRate, forKey: .sampleRate)
        try container.encode(duration, forKey: .duration)

        try? container.encodeIfPresent(bitsPerChannel, forKey: .bitsPerChannel)
        try? container.encodeIfPresent(bitRate, forKey: .bitRate)
    }
}
