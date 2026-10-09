// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataC
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A session's save is on disk when `save` returns, whether or not the session is still alive, so
/// a writer that opens the file next sees it.
@Suite(.tags(.file))
final class MetadataSaveSessionTests: BinTestCase {
    @Test(arguments: ["mp3", "aif", "flac"])
    func aSaveIsOnDiskBeforeTheSessionEnds(format: String) throws {
        let fixture = switch format {
        case "mp3": TestBundleResources.shared.tabla_mp3
        case "aif": TestBundleResources.shared.tabla_aif
        default: TestBundleResources.shared.tabla_flac
        }
        let url = try copyToBin(url: fixture)
        let session = try #require(MetadataSaveSession(path: url.path))

        let tagFile = TagFile(path: url.path)
        tagFile.dictionary = ["TITLE": "Session flushed"]
        #expect(tagFile.write(toFileRef: session.fileRef))
        #expect(session.save())

        let title = try withExtendedLifetime(session) { try TagProperties(url: url)[.title] }
        #expect(title == "Session flushed")
    }
}
