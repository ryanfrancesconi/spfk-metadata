// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// What other applications put in a FLAC, as each would write it.
enum SafetyNetFLACForeign {
    static let unknownFieldKey = "SAFETYNET_FOREIGN"
    static let unknownFieldValue = "Kept by another app"
    /// The base fixture stores two `ENCODER` fields.
    static let multiValuedFieldKey = "ENCODER"
    static let lowerCaseFieldKey = "safetynet_lower"
    static let lowerCaseFieldValue = "Written in lower case"
    static let applicationID = "SNET"
    static let applicationData = Data([0x53, 0x4E, 0x00, 0xFF, 0x20, 0x21])

    /// Two stars as the Xiph rating writer stores them: 0-100 and FMPS's 0-1, sorted by key.
    static let ratingFields = ["FMPS_RATING=0.400", "RATING=40"]
}

enum SafetyNetFLACPlant {
    enum PlantError: Error {
        case missing(String)
    }

    /// Replaces the setup save's `bext` and iXML with another recorder's, restores the base
    /// fixture's two `ENCODER` fields, vendor and `riff` chunk order, and adds an unknown field, a
    /// lower-case field, a back cover, a `CUESHEET` and another application's block.
    static func plant(in url: URL) throws {
        let base = try FLACBlocks(contentsOf: TestBundleResources.shared.tabla_flac)
        let baseComment = try base.vorbisComment().orThrow(PlantError.missing("base VORBIS_COMMENT"))
        let baseRIFF = try base.blocks(.application).filter { try $0.riffChunk() != nil }
        let leadOut = try base.totalSamples.orThrow(PlantError.missing("STREAMINFO"))

        try FLACBlockWriter.rewrite(url) { blocks in
            guard let commentIndex = blocks.firstIndex(where: { $0.blockType == .vorbisComment }) else {
                throw PlantError.missing("VORBIS_COMMENT")
            }

            let comment = try VorbisComment(blocks[commentIndex].payload)
            let fields = comment.fields.filter { $0.key.caseInsensitiveCompare(SafetyNetFLACForeign.multiValuedFieldKey) != .orderedSame }
                + baseComment.fields.filter { $0.key == SafetyNetFLACForeign.multiValuedFieldKey }
                + [
                    VorbisComment.Field(key: SafetyNetFLACForeign.unknownFieldKey, value: SafetyNetFLACForeign.unknownFieldValue),
                    VorbisComment.Field(key: SafetyNetFLACForeign.lowerCaseFieldKey, value: SafetyNetFLACForeign.lowerCaseFieldValue),
                ]

            // A different image from the front cover's, and stored before it, so a writer that
            // takes the first picture rather than the front cover is seen.
            let backCover = try FLACBlockWriter.picture(
                type: 4, mimeType: "image/jpeg", description: "Back Cover",
                data: Data(contentsOf: TestBundleResources.shared.songbird)
            )

            blocks[commentIndex] = FLACBlockWriter.vorbisComment(vendor: baseComment.vendor, fields: fields)
            blocks.insert(contentsOf: [
                backCover,
                FLACBlockWriter.cueSheet(catalog: "1234567890123", leadOut: leadOut),
                FLACBlockWriter.application(id: SafetyNetFLACForeign.applicationID, data: SafetyNetFLACForeign.applicationData),
            ], at: commentIndex + 1)

            try replaceOwnedChunk("bext", with: SafetyNetRIFFForeign.broadcastExtension, in: &blocks)
            try replaceOwnedChunk("iXML", with: Data(SafetyNetRIFFForeign.iXML.utf8), in: &blocks)

            // The fixture's own foreign chunks, back in their original order where the first was.
            guard let firstRIFF = try blocks.firstIndex(where: { try isForeignRIFF($0) }) else { throw PlantError.missing("riff blocks") }
            let others = try blocks.filter { try !isForeignRIFF($0) }
            blocks = Array(others.prefix(firstRIFF)) + baseRIFF + Array(others.dropFirst(firstRIFF))
        }
    }

    /// Removes the setup save's `bext` block, so the BEXT is held only by iXML's `<BEXT>`.
    static func plantIXMLOnlyBroadcastExtension(in url: URL) throws {
        try FLACBlockWriter.rewrite(url) { blocks in
            let iXML = try blocks.compactMap { try $0.riffChunk() }.first { $0.id == "iXML" }
            guard let iXML, String(decoding: iXML.payload, as: UTF8.self).contains("<BEXT>") else {
                throw PlantError.missing("iXML with <BEXT>")
            }

            let count = blocks.count
            blocks = try blocks.filter { try $0.riffChunk()?.id != "bext" && $0.applicationID != "bext" }
            guard blocks.count == count - 1 else { throw PlantError.missing("one bext block") }
        }
    }

    private static func isForeignRIFF(_ block: FLACBlocks.Block) throws -> Bool {
        guard let chunk = try block.riffChunk() else { return false }
        return !SafetyNetFLACItem.ownedChunkIDs.contains(chunk.id)
    }

    private static func replaceOwnedChunk(_ id: String, with payload: Data, in blocks: inout [FLACBlocks.Block]) throws {
        guard let index = try blocks.firstIndex(where: { try $0.riffChunk()?.id == id }) else { throw PlantError.missing("riff/\(id)") }
        blocks[index] = FLACBlockWriter.riff(id: id, payload: payload)
    }
}

private extension Optional {
    func orThrow(_ error: Error) throws -> Wrapped {
        guard let self else { throw error }
        return self
    }
}
