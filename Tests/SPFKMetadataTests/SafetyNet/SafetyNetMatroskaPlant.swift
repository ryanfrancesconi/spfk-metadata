// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKTesting

/// What other applications put in a Matroska file, as each would write it.
enum SafetyNetMatroskaForeign {
    static let unknownTagName = "SAFETYNET_FOREIGN"
    static let unknownTagValue = "Kept by another app"

    typealias ID = MatroskaElements.ID

    /// A tag with empty `Targets`, as ffmpeg writes its global metadata: the specification reads
    /// the missing level as 50.
    static var unknownTag: Data {
        EBML.master(ID.tag, children: EBML.element(ID.targets, Data())
            + EBML.master(ID.simpleTag, children: EBML.string(ID.tagName, unknownTagName) + EBML.string(ID.tagString, unknownTagValue)))
    }

    /// A font, which players load for subtitles.
    static var fontAttachment: Data {
        EBML.master(ID.attachedFile, children: EBML.string(ID.fileName, "SafetyNet.ttf") + EBML.string(ID.fileMediaType, "font/ttf")
            + EBML.element(ID.fileData, Data([0x00, 0x01, 0x00, 0x00, 0x00, 0x05, 0x53, 0x4E, 0x00, 0xFF])) + EBML.unsigned(ID.fileUID, 0x5AFE_7E57))
    }

    /// One edition holding one chapter at 0.1 s.
    static var chapters: Data {
        let display = EBML.master(0x80, children: EBML.string(0x85, "Another App's Chapter") + EBML.string(0x437C, "eng"))
        let atom = EBML.master(0xB6, children: EBML.unsigned(0x73C4, 0x5AFE_C4A9) + EBML.unsigned(0x91, 100_000_000) + display)
        return EBML.master(ID.chapters, children: EBML.master(0x45B9, children: atom))
    }
}

enum SafetyNetMatroskaPlant {
    /// Adds an unknown tag, a font attachment where `font` is set, and `Chapters` where the file
    /// has none.
    static func plant(in url: URL, font: Bool) throws {
        let hasChapters = try !MatroskaElements(contentsOf: url).elements(MatroskaElements.ID.chapters).isEmpty

        var grow: [(id: UInt32, children: Data)] = [(MatroskaElements.ID.tags, SafetyNetMatroskaForeign.unknownTag)]
        if font {
            grow.append((MatroskaElements.ID.attachments, SafetyNetMatroskaForeign.fontAttachment))
        }

        try MatroskaSegmentEditor.rewrite(url, grow: grow, append: hasChapters ? [] : [SafetyNetMatroskaForeign.chapters])
    }
}
