// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKAudioBase
import SPFKMetadataC

/// What a native save does with the XMP packet a WAV's `_PMX` chunk or an MP3's ID3v2 `PRIV`
/// frame stores. The bytes are written as given; nothing here parses XMP.
public enum StoredXMPPacketWrite: Sendable, Hashable {
    case keep
    case replace(String)
    case remove

    /// The formats whose packet TagLib stores beside the native chunks.
    public static let fileTypes: Set<AudioFileType> = [.wav, .mp3]

    /// The packet the file stores, as written: unlike a toolkit read, no native metadata is
    /// merged in. `nil` when there is none, or for a format outside ``fileTypes``.
    public static func storedPacket(in url: URL) -> String? {
        TagLibBridge.storedXMPPacket(url.path)
    }

    /// Calls `body` with the packet to store, `nil` to remove it; not at all for ``keep``.
    func apply(_ body: (String?) -> Void) {
        switch self {
        case .keep: break
        case let .replace(packet): body(packet)
        case .remove: body(nil)
        }
    }
}
