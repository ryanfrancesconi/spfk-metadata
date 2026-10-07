// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

enum SafetyNetOggPlant {
    enum PlantError: Error {
        case missing(String)
    }

    /// Two `ENCODER` values, kept separate as Xiph comments allow.
    static let encoders = ["SafetyNet Encoder", "Another Encoder"]

    /// Restores the base fixture's vendor and adds two `ENCODER` values, an unknown field, a
    /// lower-case field and a back cover stored before the front cover.
    static func plant(in url: URL, base: URL) throws {
        guard let vendor = try OggPackets(contentsOf: base).comment()?.vendor else { throw PlantError.missing("base comment") }

        let backCover = try FLACBlockWriter.picture(
            type: 4, mimeType: "image/jpeg", description: "Back Cover",
            data: Data(contentsOf: TestBundleResources.shared.songbird)
        ).payload.base64EncodedString()

        try OggCommentWriter.rewrite(url) { comment in
            var fields = comment.fields.filter { $0.key.caseInsensitiveCompare(SafetyNetFLACForeign.multiValuedFieldKey) != .orderedSame }

            let pictureIndex = fields.firstIndex { $0.key.uppercased() == "METADATA_BLOCK_PICTURE" } ?? fields.endIndex
            fields.insert(VorbisComment.Field(key: "METADATA_BLOCK_PICTURE", value: backCover), at: pictureIndex)

            fields += encoders.map { VorbisComment.Field(key: SafetyNetFLACForeign.multiValuedFieldKey, value: $0) } + [
                VorbisComment.Field(key: SafetyNetFLACForeign.unknownFieldKey, value: SafetyNetFLACForeign.unknownFieldValue),
                VorbisComment.Field(key: SafetyNetFLACForeign.lowerCaseFieldKey, value: SafetyNetFLACForeign.lowerCaseFieldValue),
            ]

            return (vendor, fields)
        }
    }
}
