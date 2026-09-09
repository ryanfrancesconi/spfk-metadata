// Copyright Ryan Francesconi. All Rights Reserved.

import Darwin
import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// An MP4 with `moov` ahead of `mdat` is written in place when the new tag fits the padding
/// beside `ilst`. Anything that moves `mdat` costs a pass over the whole file -- a feature film is
/// a gigabyte or more -- so the assertion is on how much was written, not on what the tags say:
/// a save that removes the atom and re-inserts it lands `mdat` at the same offset with the same
/// padding, and only the bytes it wrote to get there tell the two apart.
@Suite(.tags(.file))
final class TagFileMP4LayoutTests: BinTestCase {
    /// Appended to the fixture's `mdat`, so a save that moves it writes an unmistakable amount.
    private static let inflation = 16 * 1024 * 1024

    private struct Atom {
        let type: String
        let offset: UInt64
        let length: UInt64
    }

    private func atoms(in data: Data, from start: UInt64, to end: UInt64) -> [Atom] {
        var atoms: [Atom] = []
        var offset = start

        while offset + 8 <= end {
            let at = Int(offset)
            let size32 = data[at ..< at + 4].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            let type = String(decoding: data[at + 4 ..< at + 8], as: UTF8.self)
            let length = size32 == 0 ? end - offset : size32

            atoms.append(Atom(type: type, offset: offset, length: length))
            offset += max(length, 8)
        }

        return atoms
    }

    private func child(_ type: String, of parent: Atom, in data: Data, headerLength: UInt64 = 8) throws -> Atom {
        try #require(
            atoms(in: data, from: parent.offset + headerLength, to: parent.offset + parent.length)
                .first { $0.type == type }
        )
    }

    private struct Layout {
        let mdatOffset: UInt64
        let mdatLength: UInt64
        let ilstLength: UInt64
        /// The `free` atom right after `ilst`, which is the padding a save can write into.
        let paddingLength: UInt64
    }

    private func layout(of url: URL) throws -> Layout {
        let data = try Data(contentsOf: url)
        let top = atoms(in: data, from: 0, to: UInt64(data.count))

        let moov = try #require(top.first { $0.type == "moov" })
        let mdat = try #require(top.first { $0.type == "mdat" })
        #expect(moov.offset < mdat.offset, "the file has to carry moov ahead of mdat for this to test anything")

        let udta = try child("udta", of: moov, in: data)
        // `meta` carries a 4-byte version/flags field before its children.
        let meta = try child("meta", of: udta, in: data)
        let metaChildren = atoms(in: data, from: meta.offset + 12, to: meta.offset + meta.length)
        let ilstIndex = try #require(metaChildren.firstIndex { $0.type == "ilst" })
        let padding = metaChildren.indices.contains(ilstIndex + 1) && metaChildren[ilstIndex + 1].type == "free"
            ? metaChildren[ilstIndex + 1].length
            : 0

        return Layout(
            mdatOffset: mdat.offset,
            mdatLength: mdat.length,
            ilstLength: metaChildren[ilstIndex].length,
            paddingLength: padding
        )
    }

    /// A copy of the fixture with `mdat`, its last atom, grown by ``inflation`` bytes of zeros.
    /// The chunk offsets still point into it, and nothing here decodes what they point at.
    private func inflatedCopy() throws -> URL {
        let url = bin.appendingPathComponent("tabla.mp4")
        try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_mp4, to: url)

        let data = try Data(contentsOf: url)
        let mdat = try #require(atoms(in: data, from: 0, to: UInt64(data.count)).first { $0.type == "mdat" })
        #expect(mdat.offset + mdat.length == UInt64(data.count), "mdat has to be the last atom")

        let length = UInt32(mdat.length) + UInt32(Self.inflation)
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }

        try handle.seek(toOffset: mdat.offset)
        try handle.write(contentsOf: withUnsafeBytes(of: length.bigEndian) { Data($0) })
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(count: Self.inflation))

        return url
    }

    private func save(title: String, to url: URL) throws {
        var properties = try TagProperties(url: url)
        properties.set(tag: .title, value: title)
        try properties.save(to: url)
    }

    /// Bytes this process has handed to `write(2)` so far.
    private func logicalBytesWritten() throws -> UInt64 {
        // The kernel fills the struct at the address it is handed; the `rusage_info_t *` in the
        // signature is that address, not a pointer to be filled in.
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        try #require(status == 0)

        return info.ri_logical_writes
    }

    /// A first save leaves TagLib's own padding after `ilst`; a second that grows the tag by less
    /// than that padding must write into it, and so write far less than `mdat`'s length.
    @Test func aSmallEditWritesIntoThePaddingAndLeavesMDATInPlace() throws {
        let url = try inflatedCopy()

        try save(title: "Tabla", to: url)
        let before = try layout(of: url)
        #expect(before.paddingLength > 200)
        #expect(before.mdatLength > UInt64(Self.inflation))

        let writtenBefore = try logicalBytesWritten()
        try save(title: "Tabla " + String(repeating: "x", count: 100), to: url)
        let written = try logicalBytesWritten() - writtenBefore

        let after = try layout(of: url)
        let growth = after.ilstLength - before.ilstLength

        #expect(growth > 0)
        #expect(after.paddingLength == before.paddingLength - growth)
        #expect(after.mdatOffset == before.mdatOffset)
        #expect(written < after.mdatLength, "the save wrote \(written) bytes against an mdat of \(after.mdatLength)")
        #expect(try TagProperties(url: url).tag(for: .title)?.hasPrefix("Tabla x") == true)
    }
}
