// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import CoreGraphics
import Foundation
import ImageIO
import SPFKTesting

/// What other applications put in an MP4, as each would write it.
enum SafetyNetMP4Foreign {
    /// Mixed case, as iTunes spells its own freeform names (`iTunSMPB`).
    static let unknownFreeformName = "SafetyNet Foreign"
    static let unknownFreeformValue = "Kept by another app"
    static let otherMean = "com.example.safetynet"
    static let otherMeanName = "Foreign"
    static let otherMeanValue = "Kept by another app's own namespace"
    static let artists = ["Artist One", "Artist Two"]
    /// `rtng` 1: explicit.
    static let contentRating: UInt8 = 1
    /// The XMP box's extended type, `BE7ACFCB-97A9-42E8-9C71-999491E3AFAC`.
    static let xmpUUID = Data([0xBE, 0x7A, 0xCF, 0xCB, 0x97, 0xA9, 0x42, 0xE8, 0x9C, 0x71, 0x99, 0x94, 0x91, 0xE3, 0xAF, 0xAC])

    /// Two stars as the MP4 rating writer stores them, sorted.
    static let ratingLines = ["----:com.apple.iTunes:RATING=40", "rate=40"]
}

/// Plants the MP4 family's foreign items after the setup save. Everything inside `moov` takes its
/// room from a `free` atom there, so `moov` keeps its size and no chunk offset moves; the XMP
/// `uuid` is appended at the end of the file.
enum SafetyNetMP4Plant {
    enum PlantError: Error {
        case missing(String)
        case noRoom(needed: Int, free: Int)
    }

    static func plant(in url: URL, mediaKind: UInt8) throws {
        let gapless = try copiedAtom(["moov", "udta", "meta", "ilst"], from: TestBundleResources.shared.ituns_mpb_m4a) {
            $0.type == "----" && $0.child("name")?.payload.dropFirst(4) == Data("iTunSMPB".utf8)
        }
        let copyright = try copiedAtom(["moov", "udta"], from: TestBundleResources.shared.tabla_cprt_m4a) { $0.type == "cprt" }
        let chapters = try copiedAtom(["moov", "udta"], from: TestBundleResources.shared.tabla_cprt_m4a) { $0.type == "chpl" }

        try MP4MoovEditor.rewrite(url) { moov in
            try moov.edit(["udta", "meta", "ilst"]) { ilst in
                ilst.children.removeAll { $0.type == "©ART" }

                ilst.children += try [
                    MP4MoovEditor.Node(MP4ItemListBuilder.freeform(mean: "com.apple.iTunes", name: SafetyNetMP4Foreign.unknownFreeformName, value: SafetyNetMP4Foreign.unknownFreeformValue)),
                    MP4MoovEditor.Node(MP4ItemListBuilder.freeform(mean: SafetyNetMP4Foreign.otherMean, name: SafetyNetMP4Foreign.otherMeanName, value: SafetyNetMP4Foreign.otherMeanValue)),
                    gapless,
                    MP4MoovEditor.Node(MP4ItemListBuilder.item("stik", type: 21, value: [mediaKind])),
                    MP4MoovEditor.Node(MP4ItemListBuilder.item("rtng", type: 21, value: [SafetyNetMP4Foreign.contentRating])),
                    MP4MoovEditor.Node(type: "©ART", children: SafetyNetMP4Foreign.artists.map { MP4MoovEditor.Node.data(type: 1, value: Data($0.utf8)) }),
                ]

                // A second image after the app's own, which is the one players show.
                guard let covr = ilst.children.firstIndex(where: { $0.type == "covr" }) else { throw PlantError.missing("covr") }
                ilst.children[covr].children.append(.data(type: 14, value: try backCover()))
            }

            try moov.edit(["udta"]) { $0.children += [copyright, chapters] }
        }

        let packet = Data(SafetyNetSetup.xmpPacket(title: "Foreign").utf8)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: MP4MoovEditor.Node(type: "uuid", lead: SafetyNetMP4Foreign.xmpUUID + packet).bytes)
    }

    /// An atom from another fixture, byte for byte.
    private static func copiedAtom(_ path: [String], from url: URL, where predicate: (MP4Atoms.Box) -> Bool) throws -> MP4MoovEditor.Node {
        guard let box = try MP4Atoms(contentsOf: url).box(path)?.children.first(where: predicate) else {
            throw PlantError.missing("\(path) in \(url.lastPathComponent)")
        }
        return try MP4MoovEditor.Node(Array(box.bytes))
    }

    /// A 2x2 PNG: small enough to fit the `free` atom, and unlike any image the app writes.
    private static func backCover() throws -> Data {
        let pixels: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
        let output = NSMutableData()

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ),
              let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)
        else { throw PlantError.missing("PNG encoder") }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PlantError.missing("PNG encoder") }
        return output as Data
    }
}

/// Rewrites `moov` as a tree, then resizes a `free` atom inside it so `moov` keeps its size.
enum MP4MoovEditor {
    /// An atom: the bytes before its children (all of them for a leaf; a full box's version and
    /// flags for `meta`), its children, and any bytes after them.
    struct Node {
        var type: String
        var headerSize = 8
        var lead = Data()
        var children: [Node] = []
        var trail = Data()

        init(type: String, headerSize: Int = 8, lead: Data = Data(), children: [Node] = [], trail: Data = Data()) {
            self.type = type
            self.headerSize = headerSize
            self.lead = lead
            self.children = children
            self.trail = trail
        }

        init(_ box: MP4Atoms.Box) {
            type = box.type
            headerSize = box.headerSize
            children = box.children.map(Node.init)

            if let first = box.children.first, let last = box.children.last {
                let start = box.offset + box.headerSize
                lead = Data(box.payload.prefix(first.offset - start))
                trail = Data(box.payload.dropFirst(last.offset + last.size - start))
            } else {
                lead = box.payload
            }
        }

        /// One atom's bytes, as a builder makes them.
        init(_ bytes: [UInt8]) throws {
            guard let box = try MP4Atoms(Data(bytes)).boxes.first else { throw SafetyNetMP4Plant.PlantError.missing("atom") }
            self.init(box)
        }

        static func data(type: UInt32, value: Data) -> Node {
            Node(type: "data", lead: MP4MoovEditor.be32(type) + Data(count: 4) + value)
        }

        var size: Int {
            headerSize + lead.count + children.reduce(0) { $0 + $1.size } + trail.count
        }

        var bytes: Data {
            let typeBytes = Data(type.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) })
            let header = headerSize == 16
                ? MP4MoovEditor.be32(1) + typeBytes + MP4MoovEditor.be32(UInt32(size >> 32)) + MP4MoovEditor.be32(UInt32(truncatingIfNeeded: size))
                : MP4MoovEditor.be32(UInt32(size)) + typeBytes
            return children.reduce(header + lead) { $0 + $1.bytes } + trail
        }

        mutating func edit(_ path: [String], _ change: (inout Node) throws -> Void) throws {
            guard let first = path.first else { return try change(&self) }
            guard let index = children.firstIndex(where: { $0.type == first }) else { throw SafetyNetMP4Plant.PlantError.missing(first) }
            try children[index].edit(Array(path.dropFirst()), change)
        }

        /// Resizes the first `free` atom in the tree by `delta` bytes; false when there is none.
        mutating func resizeFree(by delta: Int) throws -> Bool {
            if type == "free" {
                guard lead.count + delta >= 0 else { throw SafetyNetMP4Plant.PlantError.noRoom(needed: -delta, free: lead.count) }
                lead = Data(count: lead.count + delta)
                return true
            }

            for index in children.indices {
                if try children[index].resizeFree(by: delta) { return true }
            }
            return false
        }
    }

    static func be32(_ value: UInt32) -> Data {
        Data([UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    }

    static func rewrite(_ url: URL, _ edit: (inout Node) throws -> Void) throws {
        let data = try Data(contentsOf: url)
        guard let moovBox = try MP4Atoms(data).box(["moov"]) else { throw SafetyNetMP4Plant.PlantError.missing("moov") }

        var moov = Node(moovBox)
        try edit(&moov)

        guard try moov.resizeFree(by: moovBox.size - moov.size) else { throw SafetyNetMP4Plant.PlantError.missing("free in moov") }
        guard moov.size == moovBox.size else { throw SafetyNetMP4Plant.PlantError.noRoom(needed: moov.size - moovBox.size, free: 0) }

        var result = data
        result.replaceSubrange(moovBox.offset ..< moovBox.offset + moovBox.size, with: moov.bytes)
        try result.write(to: url)
    }
}
