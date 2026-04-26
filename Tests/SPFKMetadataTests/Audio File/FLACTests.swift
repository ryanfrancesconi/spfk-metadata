// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadataC

// MARK: - FlacFileC bridge

/// Tests for the `FlacFileC` Objective-C bridge: load/save of iXML and BEXT
/// APPLICATION blocks in FLAC files.
@Suite(.serialized, .tags(.file))
final class FlacFileCTests: BinTestCase {
    // MARK: Load — clean file

    /// A plain FLAC file with no APPLICATION blocks should report no iXML or BEXT.
    @Test func loadCleanFLACHasNoApplicationBlocks() async throws {
        let url = TestBundleResources.shared.tabla_flac

        let flac = FlacFileC(path: url.path)
        #expect(flac.load())
        #expect(flac.iXML == nil)
        #expect(flac.bextDescriptionC == nil)
    }

    /// Loading a valid FLAC populates audioPropertiesC with non-zero values.
    @Test func loadFLACPopulatesAudioProperties() async throws {
        let url = TestBundleResources.shared.tabla_flac

        let flac = FlacFileC(path: url.path)
        #expect(flac.load())
        let props = try #require(flac.audioPropertiesC)
        #expect(props.sampleRate > 0)
        #expect(props.channelCount > 0)
        #expect(props.duration > 0)
        #expect(props.bitsPerSample > 0)
    }

    // MARK: iXML round-trip

    /// Write an iXML string to a FLAC file, reload, and verify the string survives.
    @Test func writeAndReadIXML() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        let ixml = "<BWFXML><IXML_VERSION>2.1</IXML_VERSION><PROJECT>Test Project</PROJECT></BWFXML>"

        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.iXML = ixml
        #expect(writer.save())

        let reader = FlacFileC(path: tmpfile.path)
        #expect(reader.load())
        let readBack = try #require(reader.iXML)
        #expect(readBack.contains("Test Project"))
    }

    /// Setting iXML to nil after writing should remove the APPLICATION block.
    @Test func clearIXML() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        // Write
        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.iXML = "<BWFXML><PROJECT>ToRemove</PROJECT></BWFXML>"
        #expect(writer.save())

        // Confirm present
        let check = FlacFileC(path: tmpfile.path)
        #expect(check.load())
        #expect(check.iXML != nil)

        // Clear
        check.iXML = nil
        #expect(check.save())

        // Confirm gone
        let reader = FlacFileC(path: tmpfile.path)
        #expect(reader.load())
        #expect(reader.iXML == nil)
    }

    // MARK: BEXT round-trip

    /// Write BEXT data via FlacFileC (using BEXTDescriptionC), reload, verify key fields.
    @Test func writeAndReadBEXT() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let bextC = BEXTDescriptionC()
        bextC.version = 1
        bextC.originator = "FLAC Test"
        bextC.originationDate = "2026-04-26"
        bextC.originationTime = "12:00:00"
        bextC.timeReferenceLow = 48_000
        bextC.timeReferenceHigh = 0

        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.bextDescriptionC = bextC
        #expect(writer.save())

        let reader = FlacFileC(path: tmpfile.path)
        #expect(reader.load())
        let readBext = try #require(reader.bextDescriptionC)

        #expect(readBext.originator == "FLAC Test")
        #expect(readBext.originationDate == "2026-04-26")
        #expect(readBext.originationTime == "12:00:00")
        #expect(readBext.timeReferenceLow == 48_000)
        #expect(readBext.timeReferenceHigh == 0)
    }

    /// Setting bextDescriptionC to nil after writing should remove the BEXT APPLICATION block.
    @Test func clearBEXT() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        // Write BEXT
        let bextC = BEXTDescriptionC()
        bextC.originator = "ToRemove"

        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.bextDescriptionC = bextC
        #expect(writer.save())

        // Confirm present
        let check = FlacFileC(path: tmpfile.path)
        #expect(check.load())
        #expect(check.bextDescriptionC != nil)

        // Clear
        check.bextDescriptionC = nil
        #expect(check.save())

        // Confirm gone
        let reader = FlacFileC(path: tmpfile.path)
        #expect(reader.load())
        #expect(reader.bextDescriptionC == nil)
    }

    /// Both iXML and BEXT can coexist in the same FLAC file.
    @Test func writeIXMLAndBEXTTogether() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let bextC = BEXTDescriptionC()
        bextC.originator = "Dual Test"

        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.iXML = "<BWFXML><PROJECT>DualTest</PROJECT></BWFXML>"
        writer.bextDescriptionC = bextC
        #expect(writer.save())

        let reader = FlacFileC(path: tmpfile.path)
        #expect(reader.load())
        #expect(reader.iXML != nil)
        #expect(reader.bextDescriptionC != nil)
        #expect(reader.bextDescriptionC?.originator == "Dual Test")
    }
}

// MARK: - BEXTDescription(ixmlMetadata:)

/// Tests for the `BEXTDescription.init?(ixmlMetadata:)` iXML-to-BEXT fallback
/// conversion used for Sequoia-style FLAC files that carry BEXT fields inside iXML.
@Suite(.serialized)
final class BEXTFromIXMLTests: BinTestCase {
    /// An IXMLMetadata with no BEXT fields should produce nil.
    @Test func returnsNilWhenNoBEXTContent() {
        let ixml = IXMLMetadata()
        #expect(BEXTDescription(ixmlMetadata: ixml) == nil)
    }

    /// A minimal IXMLMetadata with only originator set should produce a non-nil result.
    @Test func returnsDescriptionWhenOriginatorPresent() throws {
        var ixml = IXMLMetadata()
        ixml.bextOriginator = "Sequoia"
        let bext = try #require(BEXTDescription(ixmlMetadata: ixml))
        #expect(bext.originator == "Sequoia")
    }

    /// All mapped BEXT fields should transfer correctly.
    @Test func allFieldsMapCorrectly() throws {
        var ixml = IXMLMetadata()
        ixml.bextVersion = "1"
        ixml.bextDescriptionText = "A test description"
        ixml.bextOriginator = "TestApp"
        ixml.bextOriginatorReference = "REF123"
        ixml.bextOriginationDate = "2026-04-26"
        ixml.bextOriginationTime = "09:30:00"
        ixml.bextTimeReferenceLow = "48000"
        ixml.bextTimeReferenceHigh = "0"
        ixml.bextCodingHistory = "A=PCM,F=48000,W=24,M=stereo"
        ixml.bextUMID = "AABBCC"

        let bext = try #require(BEXTDescription(ixmlMetadata: ixml))
        #expect(bext.version == 1)
        #expect(bext.sequenceDescription == "A test description")
        #expect(bext.originator == "TestApp")
        #expect(bext.originatorReference == "REF123")
        #expect(bext.originationDate == "2026-04-26")
        #expect(bext.originationTime == "09:30:00")
        #expect(bext.timeReferenceLow == 48_000)
        #expect(bext.timeReferenceHigh == 0)
        #expect(bext.codingHistory == "A=PCM,F=48000,W=24,M=stereo")
        #expect(bext.umid == "AABBCC")
    }

    /// An IXMLMetadata with only a coding history entry should still produce a result
    /// because codingHistory is recognizable BEXT content.
    @Test func codingHistoryAloneCreatesResult() throws {
        var ixml = IXMLMetadata()
        ixml.bextCodingHistory = "A=PCM,F=48000"
        let bext = try #require(BEXTDescription(ixmlMetadata: ixml))
        #expect(bext.codingHistory == "A=PCM,F=48000")
    }

    /// Time reference low/high alone triggers init since it's recognizable BEXT content.
    @Test func timeReferenceAloneTriggersBEXTInit() throws {
        var ixml = IXMLMetadata()
        ixml.bextTimeReferenceLow = "96000"
        ixml.bextTimeReferenceHigh = "0"
        let bext = try #require(BEXTDescription(ixmlMetadata: ixml))
        #expect(bext.timeReferenceLow == 96_000)
        #expect(bext.timeReferenceHigh == 0)
    }

    /// Round-trip through IXMLMetadata xml generation and BEXTDescription(ixmlMetadata:).
    @Test func roundTripThroughXMLString() throws {
        var ixml = IXMLMetadata()
        ixml.bextOriginator = "RoundTripTest"
        ixml.bextOriginationDate = "2026-01-01"
        ixml.bextTimeReferenceLow = "192000"

        let xmlString = ixml.xml
        let reparsed = try IXMLMetadata(xml: xmlString)
        let bext = try #require(BEXTDescription(ixmlMetadata: reparsed))

        #expect(bext.originator == "RoundTripTest")
        #expect(bext.originationDate == "2026-01-01")
        #expect(bext.timeReferenceLow == 192_000)
    }
}

// MARK: - MetaAudioFileDescription FLAC end-to-end

/// End-to-end tests for `MetaAudioFileDescription` with FLAC files, covering
/// the `loadFLAC()` / `saveFLAC()` paths introduced for iXML/BEXT APPLICATION block support.
@Suite(.serialized, .tags(.file))
final class MetaAudioFileDescriptionFLACTests: BinTestCase {
    /// Parsing a plain FLAC produces valid audio format properties.
    @Test func parseFLACHasAudioFormat() async throws {
        let url = TestBundleResources.shared.tabla_flac

        let maf = try await MetaAudioFileDescription(parsing: url)
        let format = try #require(maf.audioFormat)

        #expect(format.sampleRate > 0)
        #expect(format.channelCount > 0)
        #expect(format.duration > 0)
    }

    /// Parsing a plain FLAC with no APPLICATION blocks leaves iXMLMetadata and bextDescription nil.
    @Test func parsePlainFLACHasNoIXMLOrBEXT() async throws {
        let url = TestBundleResources.shared.tabla_flac

        let maf = try await MetaAudioFileDescription(parsing: url)
        #expect(maf.iXMLMetadata == nil)
        #expect(maf.bextDescription == nil)
    }

    /// iXML written via FlacFileC is recovered by MetaAudioFileDescription.init(parsing:).
    @Test func parseFlacReadsIXML() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)
        let ixml = "<BWFXML><IXML_VERSION>2.1</IXML_VERSION><PROJECT>Integration Test</PROJECT></BWFXML>"

        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.iXML = ixml
        #expect(writer.save())

        let maf = try await MetaAudioFileDescription(parsing: tmpfile)
        let readXML = try #require(maf.iXMLMetadata)
        #expect(readXML.contains("Integration Test"))
    }

    /// BEXT written via FlacFileC is recovered by MetaAudioFileDescription.init(parsing:).
    @Test func parseFlacReadsBEXT() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        let bextC = BEXTDescriptionC()
        bextC.originator = "End-to-End Test"
        bextC.originationDate = "2026-04-26"
        bextC.timeReferenceLow = 48_000
        bextC.timeReferenceHigh = 0

        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.bextDescriptionC = bextC
        #expect(writer.save())

        let maf = try await MetaAudioFileDescription(parsing: tmpfile)
        let bext = try #require(maf.bextDescription)
        #expect(bext.originator == "End-to-End Test")
        #expect(bext.originationDate == "2026-04-26")
    }

    /// save() writes iXML and BEXT APPLICATION blocks; init(parsing:) reads them back.
    @Test func saveAndReloadIXMLAndBEXT() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        // Set up and save
        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        maf.iXMLMetadata = "<BWFXML><PROJECT>SaveTest</PROJECT></BWFXML>"
        maf.bextDescription = {
            var b = BEXTDescription()
            b.originator = "SaveOrigin"
            b.originationDate = "2026-04-26"
            b.timeReferenceLow = 96_000
            b.timeReferenceHigh = 0
            return b
        }()
        try maf.save()

        // Reload and verify
        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        let readXML = try #require(reloaded.iXMLMetadata)
        let bext = try #require(reloaded.bextDescription)

        #expect(readXML.contains("SaveTest"))
        #expect(bext.originator == "SaveOrigin")
        #expect(bext.originationDate == "2026-04-26")
        #expect(bext.timeReferenceLow == 96_000)
    }

    /// APPLICATION blocks survive a MetaAudioFileDescription tag-only save (Xiph comment rewrite).
    @Test func applicationBlocksSurviveTagSave() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        // Write APPLICATION blocks via FlacFileC first
        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.iXML = "<BWFXML><PROJECT>SurvivalTest</PROJECT></BWFXML>"
        #expect(writer.save())

        // Now save standard tag metadata via MetaAudioFileDescription (triggers Xiph rewrite)
        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        maf.tagProperties.data.set(id3Frame: .title, value: "Tag Survival Test")
        try maf.save()

        // Reload and confirm APPLICATION block survived the Xiph tag rewrite
        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        let readXML = try #require(reloaded.iXMLMetadata)
        #expect(readXML.contains("SurvivalTest"))
    }

    /// Clearing iXMLMetadata and saving removes the APPLICATION block from the FLAC file.
    @Test func clearIXMLViaMetaAudioFileDescription() async throws {
        let tmpfile = try copyToBin(url: TestBundleResources.shared.tabla_flac)

        // Write iXML
        let writer = FlacFileC(path: tmpfile.path)
        #expect(writer.load())
        writer.iXML = "<BWFXML><PROJECT>ToRemove</PROJECT></BWFXML>"
        #expect(writer.save())

        // Load, clear, save
        var maf = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(maf.iXMLMetadata != nil)
        maf.iXMLMetadata = nil
        try maf.save()

        // Confirm gone
        let reloaded = try await MetaAudioFileDescription(parsing: tmpfile)
        #expect(reloaded.iXMLMetadata == nil)
    }
}
