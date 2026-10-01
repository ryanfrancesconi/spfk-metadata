// Copyright Ryan Francesconi. All Rights Reserved.

import AEXML
import Foundation
import SPFKAudioBase
import SPFKMetadataBase
import Testing

@testable import SPFKMetadata

/// LOUDNESS is rebuilt from the model only when the model changed; numeric iXML values parse trimmed.
struct IXMLMetadataLoudnessTests {
    private func chunk(loudness: String) -> String {
        "<BWFXML><NOTE>Before</NOTE><LOUDNESS>\(loudness)</LOUDNESS></BWFXML>"
    }

    /// The LOUDNESS element of `xml`, read without trimming.
    private func loudnessElement(in xml: String) throws -> AEXMLElement? {
        var options = AEXMLOptions()
        options.parserSettings.shouldTrimWhitespace = false
        let element = try AEXMLDocument(xml: xml, options: options).root["LOUDNESS"]
        return element.error == nil ? element : nil
    }

    private func editNote(_ xml: String) throws -> String {
        var ixml = try IXMLMetadata(xml: xml)
        ixml.note = "After"
        return ixml.xml
    }

    @Test func paddedLoudnessValueParses() throws {
        let ixml = try IXMLMetadata(xml: chunk(
            loudness: "<LOUDNESS_VALUE> -23.00 </LOUDNESS_VALUE><LOUDNESS_RANGE>5.00</LOUDNESS_RANGE>"
        ))

        #expect(ixml.loudnessDescription?.loudnessIntegrated == -23)
        #expect(ixml.loudnessDescription?.loudnessRange == 5)
    }

    @Test func paddedLoudnessSurvivesAnotherFieldsEdit() throws {
        let xml = try editNote(chunk(
            loudness: "<LOUDNESS_VALUE> -23.00 </LOUDNESS_VALUE><LOUDNESS_RANGE>5.00</LOUDNESS_RANGE>"
        ))

        let reparsed = try IXMLMetadata(xml: xml)
        #expect(reparsed.note == "After")
        #expect(reparsed.loudnessDescription?.loudnessIntegrated == -23)
        #expect(reparsed.loudnessDescription?.loudnessRange == 5)
    }

    @Test func rangeOnlyLoudnessSurvivesAnotherFieldsEdit() throws {
        let xml = try editNote(chunk(loudness: "<LOUDNESS_RANGE>5.00</LOUDNESS_RANGE>"))

        let element = try #require(try loudnessElement(in: xml))
        #expect(element["LOUDNESS_RANGE"].value == "5.00")
    }

    @Test func unchangedLoudnessKeepsItsTextAndUnmodeledChildren() throws {
        let xml = try editNote(chunk(
            loudness: "<LOUDNESS_VALUE>-23.456</LOUDNESS_VALUE><VENDOR_FIELD>x</VENDOR_FIELD>"
        ))

        let element = try #require(try loudnessElement(in: xml))
        #expect(element["LOUDNESS_VALUE"].value == "-23.456")
        #expect(element["VENDOR_FIELD"].value == "x")
    }

    @Test func changedLoudnessIsWritten() throws {
        var ixml = try IXMLMetadata(xml: chunk(
            loudness: "<LOUDNESS_VALUE>-23.456</LOUDNESS_VALUE><VENDOR_FIELD>x</VENDOR_FIELD>"
        ))
        ixml.loudnessDescription = LoudnessDescription(loudnessIntegrated: -16, maxTruePeakLevel: -1)

        let element = try #require(try loudnessElement(in: ixml.xml))
        #expect(element["LOUDNESS_VALUE"].value == "-16.00")
        #expect(element["MAX_TRUE_PEAK_LEVEL"].value == "-1.00")
    }

    @Test func clearedLoudnessIsRemoved() throws {
        var ixml = try IXMLMetadata(xml: chunk(loudness: "<LOUDNESS_VALUE>-23.00</LOUDNESS_VALUE>"))
        ixml.loudnessDescription = nil

        #expect(try loudnessElement(in: ixml.xml) == nil)
    }

    @Test func paddedBEXTTimeReferenceParses() throws {
        let ixml = try IXMLMetadata(xml: """
        <BWFXML><BEXT><BWF_VERSION> 2 </BWF_VERSION>\
        <BWF_TIME_REFERENCE_LOW> 48000 </BWF_TIME_REFERENCE_LOW>\
        <BWF_TIME_REFERENCE_HIGH>\n1\n</BWF_TIME_REFERENCE_HIGH></BEXT></BWFXML>
        """)

        let bext = try #require(BEXTDescription(ixmlMetadata: ixml))
        #expect(bext.timeReferenceLow == 48000)
        #expect(bext.timeReferenceHigh == 1)
        #expect(bext.version == 2)
    }
}
