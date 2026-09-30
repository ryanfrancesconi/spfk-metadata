// Copyright Ryan Francesconi. All Rights Reserved.

import AEXML
import Foundation
import Testing

@testable import SPFKMetadata

/// Editing one iXML field keeps every other value's text exactly as read.
struct IXMLMetadataWhitespaceTests {
    private let note = "line one\nline two "
    private let userComment = " padded comment "

    private var chunk: String {
        """
        <BWFXML><PROJECT>Before</PROJECT><NOTE>\(note)</NOTE><USER><COMMENT>\(userComment)</COMMENT></USER></BWFXML>
        """
    }

    /// Read back without trimming, so the assertion sees what the chunk holds.
    private func rawValue(_ path: [String], in xml: String) throws -> String? {
        var options = AEXMLOptions()
        options.parserSettings.shouldTrimWhitespace = false
        var element = try AEXMLDocument(xml: xml, options: options).root
        for name in path { element = element[name] }
        return element.error == nil ? element.value : nil
    }

    @Test func editingAnotherFieldKeepsANoteAsRead() throws {
        var ixml = try IXMLMetadata(xml: chunk)
        #expect(ixml.note == note)

        ixml.project = "After"
        let edited = ixml.xml

        #expect(try rawValue(["PROJECT"], in: edited) == "After")
        #expect(try rawValue(["NOTE"], in: edited) == note)
        #expect(try rawValue(["USER", "COMMENT"], in: edited) == userComment)
    }

    @Test func reserializingIsIdempotent() throws {
        let indented = "<BWFXML>\n\t<PROJECT>Before</PROJECT>\n\t<USER>\n\t\t<COMMENT>\(userComment)</COMMENT>\n\t</USER>\n</BWFXML>\n"

        for source in [chunk, indented] {
            let once = try IXMLMetadata(xml: source).xml
            let twice = try IXMLMetadata(xml: once).xml

            #expect(once == twice)
        }
    }
}
