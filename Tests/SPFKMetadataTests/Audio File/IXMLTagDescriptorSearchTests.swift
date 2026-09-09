// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import Testing

@testable import SPFKMetadata

/// The two descriptor subsets shared by the search index and find-and-replace.
///
/// Both are `filter`s over `allDescriptors`, so a section added to the registry joins them by
/// default -- these pin the exclusions that are a policy decision rather than an omission.
@Suite
struct IXMLTagDescriptorSearchTests {
    @Test func searchableExcludesTechnicalSections() throws {
        let excluded: Set<IXMLSection> = [.bext, .speed, .history, .loudness]
        let leaked = IXMLTagDescriptor.searchableDescriptors.filter { excluded.contains($0.section) }

        #expect(leaked.isEmpty, "\(leaked.map(\.identifier))")
    }

    @Test func searchableCoversEveryEditableSection() throws {
        let sections = Set(IXMLTagDescriptor.searchableDescriptors.map(\.section))

        #expect(sections == [.core, .user, .aswg, .location])
    }

    @Test func replaceableIsASubsetOfSearchable() throws {
        let searchable = Set(IXMLTagDescriptor.searchableDescriptors.map(\.identifier))
        let replaceable = Set(IXMLTagDescriptor.replaceableDescriptors.map(\.identifier))

        #expect(replaceable.isSubset(of: searchable))
        #expect(replaceable.isNotEmpty)
    }

    /// A replace writes a bare string, so anything with a value format is out; and
    /// `setValue(_:for:)` silently refuses a read-only field, which would make the caller believe
    /// a replacement landed.
    @Test func replaceableIsWritableFreeTextOnly() throws {
        for descriptor in IXMLTagDescriptor.replaceableDescriptors {
            #expect(descriptor.editStyle == .text, "\(descriptor.identifier)")
            #expect(!descriptor.isReadOnly, "\(descriptor.identifier)")
        }
    }

    /// `values(for:)` resolves the USER and ASWG containers once, which is a second read path for
    /// those two sections -- it has to answer exactly what a per-descriptor loop does.
    @Test func bulkValuesAgreeWithPerDescriptorReads() throws {
        var built = IXMLMetadata()
        built.project = "ANewMovie"
        built.locationGPS = "45.5152 N, 122.6784 W"

        var user = IXMLUserFields()
        user.catID = "AIRCon"
        user.description = "  a padded description  "
        built.setUserFields(user)

        var aswg = IXMLASWGFields()
        aswg.songTitle = "Prelude"
        built.setASWGFields(aswg)

        let ixml = try IXMLMetadata(xml: built.xml)

        let bulk = ixml.values(for: IXMLTagDescriptor.searchableDescriptors)
        let individual = IXMLTagDescriptor.searchableDescriptors
            .compactMap { ixml.value(for: $0)?.trimmed }
            .filter(\.isNotEmpty)

        #expect(bulk == individual)
        #expect(bulk.contains("AIRCon"))
        #expect(bulk.contains("Prelude"))
        #expect(bulk.contains("a padded description"))
    }
}
