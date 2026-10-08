// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// A Matroska audio file in the element order ffmpeg writes: `SeekHead`, `Void`, `Info`, `Tracks`,
/// an encoder `Tags`, five-second `Cluster`s of 16-bit PCM, then `Cues`. The tags sit ahead of the
/// audio, so a save that grows them in place moves every cluster.
struct MatroskaCorpus {
    let seconds: Int

    private static let blockFrames = 4800
    private static let blocksPerCluster = 50
    private static let bytesPerFrame = 4

    func write(to url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        // Every position in the head is fixed-width, so it is written once as a placeholder and
        // again once the clusters have been measured.
        let placeholder = head(cuesPosition: 0, segmentSize: 0)
        try handle.write(contentsOf: placeholder.data)

        var position = UInt64(placeholder.data.count - placeholder.segmentDataOffset)
        var cuePoints = Data()
        var noise = NoiseSource()
        let blockCount = seconds * 48000 / Self.blockFrames
        var block = 0

        while block < blockCount {
            let timestamp = UInt64(block * Self.blockFrames * 1000 / 48000)
            var payload = EBML.uint(0xE7, timestamp)

            for index in 0 ..< min(Self.blocksPerCluster, blockCount - block) {
                let relative = UInt16(index * Self.blockFrames * 1000 / 48000)
                let header = Data([0x81]) + be16(Int(relative)) + Data([0x80])
                payload += EBML.element(0xA3, header + noise.bytes(Self.blockFrames * Self.bytesPerFrame))
            }

            let cluster = EBML.element(0x1F43_B675, payload)
            try handle.write(contentsOf: cluster)

            let trackPosition = EBML.uint(0xF7, 1) + EBML.uint(0xF1, position)
            cuePoints += EBML.element(0xBB, EBML.uint(0xB3, timestamp) + EBML.element(0xB7, trackPosition))

            position += UInt64(cluster.count)
            block += Self.blocksPerCluster
        }

        let cues = EBML.element(0x1C53_BB6B, cuePoints)
        try handle.write(contentsOf: cues)

        let final = head(cuesPosition: position, segmentSize: position + UInt64(cues.count))
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: final.data)
    }

    /// The EBML header and everything in the segment ahead of the first cluster.
    private func head(cuesPosition: UInt64, segmentSize: UInt64) -> (data: Data, segmentDataOffset: Int) {
        let ebmlHeader = EBML.element(0x1A45_DFA3,
                                      EBML.uint(0x4286, 1) + EBML.uint(0x42F7, 1) + EBML.uint(0x42F2, 4) + EBML.uint(0x42F3, 8)
                                          + EBML.string(0x4282, "matroska") + EBML.uint(0x4287, 4) + EBML.uint(0x4285, 2))

        let info = EBML.element(0x1549_A966,
                                EBML.uint(0x2AD7B1, 1_000_000) + EBML.string(0x4D80, "spfk-metadata-bench")
                                    + EBML.string(0x5741, "spfk-metadata-bench") + EBML.float(0x4489, Double(seconds * 1000)))

        let audio = EBML.element(0xE1, EBML.float(0xB5, 48000) + EBML.uint(0x9F, 2) + EBML.uint(0x6264, 16))
        let trackEntry = EBML.uint(0xD7, 1) + EBML.uint(0x73C5, 0x5350_464B) + EBML.uint(0x83, 2)
            + EBML.string(0x86, "A_PCM/INT/LIT") + audio
        let tracks = EBML.element(0x1654_AE6B, EBML.element(0xAE, trackEntry))

        let simpleTag = EBML.element(0x67C8, EBML.string(0x45A3, "ENCODER") + EBML.string(0x4487, "spfk-metadata-bench"))
        let tags = EBML.element(0x1254_C367, EBML.element(0x7373, EBML.element(0x63C0, Data()) + simpleTag))

        let void = EBML.element(0xEC, Data(count: 82))

        func seekHead(infoPosition: UInt64) -> Data {
            let entries: [(UInt32, UInt64)] = [
                (0x1549_A966, infoPosition),
                (0x1654_AE6B, infoPosition + UInt64(info.count)),
                (0x1254_C367, infoPosition + UInt64(info.count + tracks.count)),
                (0x1C53_BB6B, cuesPosition),
            ]
            let seeks = entries.map { id, position in
                EBML.element(0x4DBB, EBML.element(0x53AB, EBML.id(id)) + EBML.uint(0x53AC, position, width: 8))
            }
            return EBML.element(0x114D_9B74, seeks.reduce(Data(), +))
        }

        let seekHeadLength = seekHead(infoPosition: 0).count
        let segmentData = seekHead(infoPosition: UInt64(seekHeadLength + void.count)) + void + info + tracks + tags
        let segmentHeader = EBML.id(0x1853_8067) + EBML.size(Int(segmentSize), width: 8)

        return (ebmlHeader + segmentHeader + segmentData, ebmlHeader.count + segmentHeader.count)
    }
}

/// EBML element encoding: an ID with its marker bits, a variable-length size, the payload.
private enum EBML {
    static func element(_ id: UInt32, _ payload: Data) -> Data {
        Self.id(id) + size(payload.count) + payload
    }

    static func id(_ id: UInt32) -> Data {
        let bytes = withUnsafeBytes(of: id.bigEndian) { Data($0) }
        return bytes.drop { $0 == 0 }
    }

    /// The shortest size field that holds `value`, or exactly `width` bytes.
    static func size(_ value: Int, width: Int? = nil) -> Data {
        let length = width ?? (1 ... 8).first { value < (1 << (7 * $0)) - 1 } ?? 8
        let marked = UInt64(value) | (1 << UInt64(7 * length))
        return withUnsafeBytes(of: marked.bigEndian) { Data($0.suffix(length)) }
    }

    static func uint(_ id: UInt32, _ value: UInt64, width: Int? = nil) -> Data {
        let length = width ?? max(1, (value.bitWidth - value.leadingZeroBitCount + 7) / 8)
        let bytes = withUnsafeBytes(of: value.bigEndian) { Data($0.suffix(length)) }
        return element(id, bytes)
    }

    static func float(_ id: UInt32, _ value: Double) -> Data {
        element(id, withUnsafeBytes(of: value.bitPattern.bigEndian) { Data($0) })
    }

    static func string(_ id: UInt32, _ value: String) -> Data {
        element(id, Data(value.utf8))
    }
}
