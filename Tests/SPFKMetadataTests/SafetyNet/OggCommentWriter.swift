// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// Replaces an Ogg Vorbis or Opus file's comment, for planting what another application would
/// have written. The headers after the first are repaged; every later page keeps its bytes and
/// granule, and is renumbered and re-checksummed.
enum OggCommentWriter {
    enum WriteError: Error {
        case unexpectedLayout(String)
    }

    typealias Page = OggPackets.Page

    /// Hands the current comment to `edit` and writes back the vendor and fields it returns.
    static func rewrite(_ url: URL, _ edit: (VorbisComment) throws -> (vendor: String, fields: [VorbisComment.Field])) throws {
        let ogg = try OggPackets(contentsOf: url)
        let headerCount = ogg.headerPacketCount

        guard let first = ogg.pages.first, ogg.packets.count >= headerCount, ogg.packets[0].lastPage == 0,
              first.lacingValues.count == ogg.packets[0].data.count / 255 + 1
        else { throw WriteError.unexpectedLayout("the identification header is not alone on the first page") }

        guard let comment = try ogg.comment() else { throw WriteError.unexpectedLayout("no comment header") }

        let (vendor, fields) = try edit(comment)
        let body = FLACBlockWriter.vorbisComment(vendor: vendor, fields: fields).payload
        let isOpus = headerCount == 2
        let commentPacket = isOpus ? OggPackets.opusTagsMagic + body : OggPackets.vorbisCommentMagic + body + Data([0x01])

        let headers = [commentPacket] + ogg.packets[2 ..< headerCount].map(\.data)
        let headerPages = pages(for: headers, serialNumber: first.serialNumber, firstSequenceNumber: 1)

        let audio = ogg.audioPages.enumerated().map { offset, page in
            Page(
                headerType: page.headerType, granulePosition: page.granulePosition, serialNumber: page.serialNumber,
                sequenceNumber: UInt32(1 + headerPages.count + offset), lacingValues: page.lacingValues, body: page.body
            )
        }

        try ([first] + headerPages + audio).reduce(into: Data()) { $0 += $1.encoded }.write(to: url)
    }

    /// `packets` laced into pages of at most 255 segments, a page that starts mid-packet flagged as
    /// continued, as libvorbis and libopus flush their headers.
    private static func pages(for packets: [Data], serialNumber: UInt32, firstSequenceNumber: UInt32) -> [Page] {
        var segments: [(lacing: UInt8, bytes: Data, endsPacket: Bool)] = []

        for packet in packets {
            var offset = 0
            repeat {
                let count = min(255, packet.count - offset)
                let ends = count < 255
                segments.append((UInt8(count), packet.subdata(in: offset ..< offset + count), ends))
                offset += count
                if ends { break }
            } while true
        }

        var pages: [Page] = []
        var continued = false

        for start in stride(from: 0, to: segments.count, by: 255) {
            let slice = segments[start ..< min(start + 255, segments.count)]
            pages.append(Page(
                // -1 on a page where no packet ends.
                headerType: continued ? 0x01 : 0, granulePosition: slice.contains { $0.endsPacket } ? 0 : .max, serialNumber: serialNumber,
                sequenceNumber: firstSequenceNumber + UInt32(pages.count), lacingValues: slice.map(\.lacing),
                body: slice.reduce(into: Data()) { $0 += $1.bytes }
            ))
            continued = slice.last?.endsPacket == false
        }

        return pages
    }
}
