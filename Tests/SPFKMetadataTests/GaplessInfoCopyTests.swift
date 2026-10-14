// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// iTunSMPB describes the encoding it was written with, so it never travels to another file.
@Suite(.tags(.file))
class GaplessInfoCopyTests: BinTestCase {
    @Test func copyingTagsLeavesTheSourceGaplessInfoBehind() throws {
        let source = TestBundleResources.shared.ituns_mpb_m4a
        let destination = try copyToBin(url: TestBundleResources.shared.tabla_cprt_m4a)

        #expect(try TagProperties(url: source).data.customTags.keys.contains("ITUNSMPB"))

        try TagProperties.copyTags(from: source, to: destination)

        let bytes = try Data(contentsOf: destination)
        #expect(bytes.range(of: Data("ITUNSMPB".utf8)) == nil)
        #expect(bytes.range(of: Data("iTunSMPB".utf8)) == nil)
        #expect(try TagProperties(url: destination).data.customTags["ITUNSMPB"] == nil)
    }
}
