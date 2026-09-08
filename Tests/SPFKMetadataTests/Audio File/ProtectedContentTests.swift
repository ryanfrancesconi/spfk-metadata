// Copyright Ryan Francesconi. All Rights Reserved.

import AVFoundation
import Foundation
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// The protected-content read runs on the audio containers of the MPEG-4 family, not only the
/// video ones, so a FairPlay audiobook is kept out of the waveform scan and the transport.
@Suite(.tags(.file))
struct ProtectedContentTests {
    /// The read must not mark an ordinary purchase-shaped container.
    @Test func anUnprotectedAudioContainerParsesAsUnprotected() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.tabla_m4a)

        #expect(description.isProtected == false)
        #expect(description.isPlayable)
    }

    @Test func anUnprotectedVideoContainerParsesAsUnprotected() async throws {
        let description = try await MetaAudioFileDescription(parsing: TestBundleResources.shared.tabla_mp4)

        #expect(description.isProtected == false)
        #expect(description.isPlayable)
    }
}

/// Parses the file named by `SPFK_PROTECTED_MEDIA` (as `TEST_RUNNER_SPFK_PROTECTED_MEDIA` under
/// `xcodebuild`) and prints what the import would store for it. Point it at a protected `.m4b`
/// or `.m4v`; there is no such fixture in the bundle.
@Suite(.tags(.development), .enabled(if: ProtectedMediaFixture.url != nil))
struct ProtectedMediaParseDevelopmentTests {
    @Test func parseProtectedMedia() async throws {
        let url = try #require(ProtectedMediaFixture.url)
        let description = try await MetaAudioFileDescription(parsing: url)

        print("PROTECTED: fileType \(String(describing: description.fileType))")
        print("PROTECTED: isAVPlayable \(description.isAVPlayable) isDecodable \(description.isDecodable)")
        print("PROTECTED: isProtected \(description.isProtected) isPlayable \(description.isPlayable)")
        print("PROTECTED: audioTracks \(description.audioTracks)")
        print("PROTECTED: markers \(description.markerCollection.markerDescriptions.count)")
    }
}

enum ProtectedMediaFixture {
    static var url: URL? {
        guard let path = ProcessInfo.processInfo.environment["SPFK_PROTECTED_MEDIA"], path.isEmpty == false else {
            return nil
        }

        let url = URL(fileURLWithPath: path)

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
