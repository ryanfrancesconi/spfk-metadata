// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// A RIFF file's top-level chunk IDs and offsets, read from the headers alone so a 1 GiB file
/// costs a few dozen reads.
struct RIFFLayout: CustomStringConvertible {
    struct Entry {
        let id: String
        let offset: UInt64
        let size: UInt64
    }

    let entries: [Entry]

    init(url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let fileSize = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        let header = try handle.read(upToCount: 12) ?? Data()
        guard header.count == 12 else { throw BenchError("\(url.lastPathComponent) is not RIFF") }

        let isLongForm = header.prefix(4) != Data("RIFF".utf8)
        var longDataSize: UInt64?
        var offset: UInt64 = 12
        var entries: [Entry] = []

        while offset + 8 <= fileSize {
            try handle.seek(toOffset: offset)
            guard let chunkHeader = try handle.read(upToCount: 8), chunkHeader.count == 8 else { break }

            let id = String(decoding: chunkHeader.prefix(4), as: UTF8.self)
            var size = UInt64(chunkHeader.dropFirst(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)

            if isLongForm, id == "ds64", let payload = try handle.read(upToCount: 16), payload.count == 16 {
                longDataSize = payload.dropFirst(8).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian
            }
            if isLongForm, id == "data", size == 0xFFFF_FFFF, let longDataSize {
                size = longDataSize
            }

            entries.append(Entry(id: id, offset: offset, size: size))
            offset += 8 + size + size % 2
        }

        self.entries = entries
    }

    var dataOffset: UInt64? {
        entries.first { $0.id == "data" }?.offset
    }

    /// `fmt  data bext(602) …`, sizes given for everything but the format and the audio.
    var description: String {
        entries.map { ["fmt ", "data", "ds64"].contains($0.id) ? $0.id : "\($0.id)(\($0.size))" }.joined(separator: " ")
    }
}
