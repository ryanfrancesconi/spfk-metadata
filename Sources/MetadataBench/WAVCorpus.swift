// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// The WAV files the bench saves, written byte by byte rather than through the code under test, so
/// a change to the save path cannot change the corpus it is measured on.
enum WAVLayout: String, CaseIterable {
    /// `bext`, `iXML`, `fmt `, `data` — metadata ahead of the audio, as a field recorder writes it.
    case recorder
    /// `fmt `, `data`, `bext`, `iXML`, `ID3 `, `LIST/INFO` — where a save leaves everything.
    case trailing
    /// `trailing` with a 4.8 MB front cover in the ID3 tag.
    case trailingArt = "trailing-art"
    /// `recorder` as RF64: a leading `ds64`, both 32-bit sizes the sentinel.
    case rf64
}

struct WAVCorpus {
    let directory: URL
    let audioBytes: Int

    /// The front cover the `trailing-art` layout carries.
    let coverURL: URL

    init(directory: URL, audioBytes: Int, coverURL: URL) {
        self.directory = directory
        self.audioBytes = audioBytes - audioBytes % 4
        self.coverURL = coverURL
    }

    func url(for layout: WAVLayout) -> URL {
        directory.appendingPathComponent("master-\(layout.rawValue).wav")
    }

    /// Writes one layout's master file.
    func write(_ layout: WAVLayout) throws -> URL {
        let url = url(for: layout)
        let bext = chunk("bext", Self.bextPayload())
        let ixml = chunk("iXML", Data(Self.ixml.utf8))
        let format = chunk("fmt ", Self.formatPayload)

        let head: Data
        let tail: Data

        switch layout {
        case .recorder:
            head = bext + ixml + format
            tail = Data()
        case .trailing:
            head = format
            tail = bext + ixml + chunk("ID3 ", try Self.id3Tag(artwork: nil)) + Self.infoList
        case .trailingArt:
            head = format
            tail = bext + ixml + chunk("ID3 ", try Self.id3Tag(artwork: Data(contentsOf: coverURL))) + Self.infoList
        case .rf64:
            head = chunk("ds64", Data(count: 28)) + bext + ixml + format
            tail = Data()
        }

        let dataHeader = Data("data".utf8) + le32(layout == .rf64 ? 0xFFFF_FFFF : UInt32(audioBytes))
        let riffSize = 4 + head.count + dataHeader.count + audioBytes + tail.count

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        if layout == .rf64 {
            try handle.write(contentsOf: Data("RF64".utf8) + le32(0xFFFF_FFFF) + Data("WAVE".utf8))
            let sampleCount = UInt64(audioBytes / Self.blockAlign)
            let ds64 = le64(UInt64(riffSize)) + le64(UInt64(audioBytes)) + le64(sampleCount) + le32(0)
            try handle.write(contentsOf: Data("ds64".utf8) + le32(28) + ds64 + head.dropFirst(36))
        } else {
            try handle.write(contentsOf: Data("RIFF".utf8) + le32(UInt32(riffSize)) + Data("WAVE".utf8) + head)
        }

        try handle.write(contentsOf: dataHeader)
        try Self.writeAudio(byteCount: audioBytes, to: handle)
        try handle.write(contentsOf: tail)
        return url
    }

    // MARK: - Payloads

    static let blockAlign = 4

    /// 48 kHz, 16-bit stereo PCM.
    static let formatPayload: Data = le16(1) + le16(2) + le32(48000) + le32(48000 * 4) + le16(blockAlign) + le16(16)

    static let ixml = #"<?xml version="1.0" encoding="UTF-8"?><BWFXML><PROJECT>Bench</PROJECT><SCENE>1</SCENE><TAKE>2</TAKE></BWFXML>"#

    /// The 602-byte fixed part (EBU Tech 3285 v2) with a description, originator and date set.
    static func bextPayload() -> Data {
        var data = Data(count: 602)
        func put(_ text: String, at offset: Int) {
            let bytes = Data(text.utf8)
            data.replaceSubrange(offset ..< offset + bytes.count, with: bytes)
        }
        put("Bench recording", at: 0)
        put("Recorder", at: 256)
        put("2026-10-07", at: 320)
        put("12:00:00", at: 330)
        data.replaceSubrange(346 ..< 348, with: le16(2))
        return data
    }

    static var infoList: Data {
        let name = Data("Bench title\0".utf8)
        return chunk("LIST", Data("INFO".utf8) + chunk("INAM", name))
    }

    /// An ID3v2.4 tag holding a title and, when given, a front-cover APIC.
    static func id3Tag(artwork: Data?) throws -> Data {
        var frames = id3Frame("TIT2", Data([3]) + Data("Bench title".utf8))

        if let artwork {
            frames += id3Frame("APIC", Data([0]) + Data("image/jpeg".utf8) + Data([0, 3, 0]) + artwork)
        }

        return Data("ID3".utf8) + Data([4, 0, 0]) + syncsafe(frames.count) + frames
    }

    private static func id3Frame(_ id: String, _ payload: Data) -> Data {
        Data(id.utf8) + syncsafe(payload.count) + Data([0, 0]) + payload
    }

    private static func syncsafe(_ value: Int) -> Data {
        Data([UInt8(value >> 21 & 0x7F), UInt8(value >> 14 & 0x7F), UInt8(value >> 7 & 0x7F), UInt8(value & 0x7F)])
    }

    /// Patterned rather than zero, so a moved block cannot read back as unchanged.
    static func writeAudio(byteCount: Int, to handle: FileHandle) throws {
        let blockSize = 1 << 20
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        var block = [UInt64](repeating: 0, count: blockSize / 8)
        var remaining = byteCount

        while remaining > 0 {
            for index in block.indices {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                block[index] = state
            }
            let count = min(remaining, blockSize)
            try block.withUnsafeBytes { try handle.write(contentsOf: Data($0.prefix(count))) }
            remaining -= count
        }
    }
}

// MARK: - Encoding

func chunk(_ id: String, _ payload: Data) -> Data {
    var data = Data(id.utf8) + le32(UInt32(payload.count)) + payload
    if payload.count.isMultiple(of: 2) == false { data.append(0) }
    return data
}

func le16(_ value: Int) -> Data {
    withUnsafeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian) { Data($0) }
}

func le32(_ value: UInt32) -> Data {
    withUnsafeBytes(of: value.littleEndian) { Data($0) }
}

func le32(_ value: Int) -> Data {
    le32(UInt32(truncatingIfNeeded: value))
}

func le64(_ value: UInt64) -> Data {
    withUnsafeBytes(of: value.littleEndian) { Data($0) }
}

struct BenchError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
