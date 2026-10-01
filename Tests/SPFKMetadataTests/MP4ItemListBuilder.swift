// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// Reads and plants `moov/udta/meta/ilst` items without any metadata library.
enum MP4ItemListBuilder {
    enum BuildError: Error {
        case noItemList(URL)
        case noRoom(URL)
    }

    /// `key` is the atom type, or `----:<mean>:<name>` for a freeform atom. `type` is the `data`
    /// atom's version and type indicator.
    struct Item: Equatable, CustomStringConvertible {
        let key: String
        let type: UInt32
        let value: [UInt8]

        var description: String { "\(key) type \(type) value \(value)" }
    }

    private struct Box {
        let type: String
        let start: Int
        let size: Int

        var end: Int { start + size }
        var body: Range<Int> { start + 8 ..< end }
    }

    // MARK: - Reading

    static func items(in url: URL) throws -> [Item] {
        let bytes = try [UInt8](Data(contentsOf: url))
        guard let ilst = itemListPath(bytes)?.last else { return [] }

        return children(bytes, in: ilst.body).compactMap { item in
            let parts = children(bytes, in: item.body)
            guard let data = parts.first(where: { $0.type == "data" }), data.size >= 16 else { return nil }

            let type = uint32(bytes, at: data.start + 8)
            let value = Array(bytes[data.start + 16 ..< data.end])

            guard item.type == "----" else {
                return Item(key: item.type, type: type, value: value)
            }

            func string(_ name: String) -> String {
                guard let box = parts.first(where: { $0.type == name }), box.size >= 12 else { return "" }
                return String(decoding: bytes[box.start + 12 ..< box.end], as: UTF8.self)
            }

            return Item(key: "----:\(string("mean")):\(string("name"))", type: type, value: value)
        }
    }

    // MARK: - Building

    static func item(_ code: String, type: UInt32, value: [UInt8]) -> [UInt8] {
        box(code, payload: dataBox(type: type, value: value))
    }

    /// A UTF-8 freeform item.
    static func freeform(mean: String, name: String, value: String) -> [UInt8] {
        let payload = fullBox("mean", payload: Array(mean.utf8))
            + fullBox("name", payload: Array(name.utf8))
            + dataBox(type: 1, value: Array(value.utf8))
        return box("----", payload: payload)
    }

    /// Appends `items` to the end of `ilst`. Takes the room from a `free` atom following `ilst`
    /// in `meta` when there is one large enough, so no chunk offset moves; otherwise requires
    /// `moov` to follow every `mdat`, and grows the boxes around `ilst`.
    static func append(_ items: [[UInt8]], to url: URL) throws {
        var bytes = try [UInt8](Data(contentsOf: url))
        guard let path = itemListPath(bytes), let ilst = path.last else { throw BuildError.noItemList(url) }

        let insert = items.flatMap { $0 }
        let count = insert.count
        let meta = path[2]
        let metaChildren = children(bytes, in: meta.start + 12 ..< meta.end)

        if let free = metaChildren.first(where: { $0.type == "free" && $0.start == ilst.end }),
           free.size >= count + 8
        {
            let shrunk = free.size - count
            let replacement = insert + be32(UInt32(shrunk)) + Array("free".utf8) + [UInt8](repeating: 0, count: shrunk - 8)
            bytes.replaceSubrange(free.start ..< free.end, with: replacement)
            setSize(&bytes, of: ilst, to: ilst.size + count)

        } else {
            let mdatAfterMoov = children(bytes, in: 0 ..< bytes.count)
                .contains { $0.type == "mdat" && $0.start > path[0].start }

            guard !mdatAfterMoov else { throw BuildError.noRoom(url) }

            bytes.insert(contentsOf: insert, at: ilst.end)
            for box in path { setSize(&bytes, of: box, to: box.size + count) }
        }

        try Data(bytes).write(to: url)
    }

    // MARK: - Boxes

    /// `moov`, `udta`, `meta`, `ilst`; `meta` is a full box, its children 4 bytes past its header.
    private static func itemListPath(_ bytes: [UInt8]) -> [Box]? {
        guard let moov = children(bytes, in: 0 ..< bytes.count).first(where: { $0.type == "moov" }),
              let udta = children(bytes, in: moov.body).first(where: { $0.type == "udta" }),
              let meta = children(bytes, in: udta.body).first(where: { $0.type == "meta" }),
              let ilst = children(bytes, in: meta.start + 12 ..< meta.end).first(where: { $0.type == "ilst" })
        else { return nil }

        return [moov, udta, meta, ilst]
    }

    private static func children(_ bytes: [UInt8], in range: Range<Int>) -> [Box] {
        var boxes: [Box] = []
        var offset = range.lowerBound

        while offset + 8 <= range.upperBound {
            let size = Int(uint32(bytes, at: offset))
            guard size >= 8, offset + size <= range.upperBound else { break }

            let type = String(bytes[offset + 4 ..< offset + 8].map { Character(Unicode.Scalar($0)) })
            boxes.append(Box(type: type, start: offset, size: size))
            offset += size
        }

        return boxes
    }

    private static func box(_ type: String, payload: [UInt8]) -> [UInt8] {
        be32(UInt32(8 + payload.count)) + type.unicodeScalars.map { UInt8($0.value) } + payload
    }

    private static func fullBox(_ type: String, payload: [UInt8]) -> [UInt8] {
        box(type, payload: [0, 0, 0, 0] + payload)
    }

    /// Type indicator, then a zero locale.
    private static func dataBox(type: UInt32, value: [UInt8]) -> [UInt8] {
        box("data", payload: be32(type) + [0, 0, 0, 0] + value)
    }

    private static func setSize(_ bytes: inout [UInt8], of box: Box, to size: Int) {
        bytes.replaceSubrange(box.start ..< box.start + 4, with: be32(UInt32(size)))
    }

    private static func be32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    private static func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        bytes[offset ..< offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
    }
}
