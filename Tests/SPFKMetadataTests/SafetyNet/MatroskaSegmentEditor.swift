// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// Plants elements in a Matroska file without moving any Cluster: an element that must grow is
/// moved to the end of the Segment, a `Void` of its size left behind, and the SeekHead is rebuilt
/// in the space its trailing `Void` gives it.
enum MatroskaSegmentEditor {
    enum EditError: Error {
        case unexpectedLayout(String)
    }

    typealias ID = MatroskaElements.ID

    /// Moves the first element with each ID in `grow` to the end with the extra children appended,
    /// then appends `append`. The Segment must be the file's last element and have a known size.
    static func rewrite(_ url: URL, grow: [(id: UInt32, children: Data)], append: [Data]) throws {
        var data = try Data(contentsOf: url)
        let file = try MatroskaElements(data)
        let segment = file.segment

        guard segment.offset + segment.size == data.count else { throw EditError.unexpectedLayout("the Segment is not last") }

        var tail = Data()
        var movedPositions: [UInt32: Int] = [:]

        for (id, children) in grow {
            guard let element = file.elements(id).first else { throw EditError.unexpectedLayout("no 0x\(String(id, radix: 16))") }

            movedPositions[id] = data.count + tail.count - file.segmentDataOffset
            tail += EBML.master(id, children: element.children.filter { $0.id != EBML.crcID }.map { EBML.bytes(of: $0, in: data) }.reduce(Data(), +) + children,
                                checksummed: element.children.first?.id == EBML.crcID)
            data.replaceSubrange(element.offset ..< element.offset + element.size, with: try EBML.void(length: element.size))
        }

        tail += append.reduce(Data(), +)

        try rewriteSeekHead(in: &data, file: file, movedPositions: movedPositions)

        let sizeWidth = segment.headerSize - EBML.id(ID.segment).count
        data.replaceSubrange(segment.offset + segment.headerSize - sizeWidth ..< segment.offset + segment.headerSize,
                             with: try EBML.size(segment.payload.count + tail.count, width: sizeWidth))
        data += tail
        try data.write(to: url)
    }

    /// Points each moved element's Seek at its new position, keeping the SeekHead and the `Void`
    /// after it the same length together.
    private static func rewriteSeekHead(in data: inout Data, file: MatroskaElements, movedPositions: [UInt32: Int]) throws {
        guard !movedPositions.isEmpty, let seekHead = file.segment.child(ID.seekHead) else { return }

        let children = file.segment.children
        guard let index = children.firstIndex(where: { $0.id == ID.seekHead }), index + 1 < children.count, children[index + 1].id == ID.void else {
            throw EditError.unexpectedLayout("no Void after the SeekHead")
        }

        let seeks = seekHead.children.filter { $0.id != EBML.crcID }.map { seek -> Data in
            guard seek.id == ID.seek, let target = seek.child(ID.seekID), let position = movedPositions[UInt32(truncatingIfNeeded: target.unsignedValue)] else {
                return EBML.bytes(of: seek, in: data)
            }
            return EBML.master(ID.seek, children: EBML.bytes(of: target, in: data) + EBML.unsigned(ID.seekPosition, UInt64(position)))
        }.reduce(Data(), +)

        let rebuilt = EBML.master(ID.seekHead, children: seeks, checksummed: seekHead.children.first?.id == EBML.crcID)
        let span = seekHead.size + children[index + 1].size
        guard span - rebuilt.count >= 2 else { throw EditError.unexpectedLayout("no room for the SeekHead") }

        data.replaceSubrange(seekHead.offset ..< seekHead.offset + span, with: rebuilt + (try EBML.void(length: span - rebuilt.count)))
    }
}

/// EBML encoding for building planted elements.
enum EBML {
    static let crcID: UInt32 = 0xBF

    static func id(_ value: UInt32) -> Data {
        let length = value > 0xFF_FFFF ? 4 : value > 0xFFFF ? 3 : value > 0xFF ? 2 : 1
        return Data((0 ..< length).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * UInt32($0))) })
    }

    /// The shortest size vint.
    static func size(_ value: Int) -> Data {
        vint(value, length: (1 ... 8).first { value < (1 << (7 * $0)) - 1 } ?? 8)
    }

    /// A size vint exactly `width` bytes long.
    static func size(_ value: Int, width: Int) throws -> Data {
        guard value < (1 << (7 * width)) - 1 else { throw MatroskaSegmentEditor.EditError.unexpectedLayout("size \(value) in \(width) bytes") }
        return vint(value, length: width)
    }

    private static func vint(_ value: Int, length: Int) -> Data {
        var bytes = (0 ..< length).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
        bytes[0] |= UInt8(0x80 >> (length - 1))
        return Data(bytes)
    }

    static func element(_ id: UInt32, _ payload: Data) -> Data {
        self.id(id) + size(payload.count) + payload
    }

    /// A master element, with a CRC-32 child first when the element it replaces carried one.
    static func master(_ id: UInt32, children: Data, checksummed: Bool = false) -> Data {
        guard checksummed else { return element(id, children) }
        let crc = withUnsafeBytes(of: crc32(children).littleEndian) { Data($0) }
        return element(id, element(crcID, crc) + children)
    }

    static func unsigned(_ id: UInt32, _ value: UInt64) -> Data {
        let length = max(1, (64 - value.leadingZeroBitCount + 7) / 8)
        return element(id, Data((0 ..< length).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * UInt64($0))) }))
    }

    static func string(_ id: UInt32, _ value: String) -> Data {
        element(id, Data(value.utf8))
    }

    /// A `Void` exactly `length` bytes long, header included; at least 2.
    static func void(length: Int) throws -> Data {
        let width = length >= 9 ? 8 : 1
        return try id(MatroskaElements.ID.void) + size(length - 1 - width, width: width) + Data(count: length - 1 - width)
    }

    /// An element's bytes as stored, header included.
    static func bytes(of element: MatroskaElements.Element, in data: Data) -> Data {
        data.subdata(in: element.offset ..< element.offset + element.size)
    }

    /// The IEEE CRC-32 EBML's CRC-32 element stores, little-endian.
    static func crc32(_ data: Data) -> UInt32 {
        crcTable.withUnsafeBufferPointer { table in
            data.withUnsafeBytes { bytes in
                ~bytes.reduce(UInt32.max) { crc, byte in table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ crc >> 8 }
            }
        }
    }

    private static let crcTable: [UInt32] = (0 ..< 256).map { index in
        (0 ..< 8).reduce(UInt32(index)) { value, _ in value & 1 != 0 ? value >> 1 ^ 0xEDB8_8320 : value >> 1 }
    }
}
