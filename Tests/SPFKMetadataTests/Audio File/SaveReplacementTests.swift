// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import AVFoundation
import CoreGraphics
import Darwin
import Foundation
import SPFKBase
import SPFKImage
import SPFKMetadataBase
import SPFKTesting
import Testing

@testable import SPFKMetadata

/// A save that has to move the audio writes a new file and swaps it in whole, keeping what the
/// file carries outside its content; one that fits in place, or that a swap would harm, rewrites
/// the file in place.
@Suite(.tags(.file))
final class SaveReplacementTests: BinTestCase {
    private func inode(_ url: URL) -> UInt64 {
        var info = stat()
        stat(url.path, &info)
        return UInt64(info.st_ino)
    }

    /// Adds artwork, which outgrows any padding ahead of an MP3's audio.
    private func saveArtwork(to url: URL) async throws {
        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Replaced"
        description.imageDescription.cgImage = try CGImage.contentsOf(url: TestBundleResources.shared.sharksandwich)
        try description.save(dirtyFlags: [.tags, .image])
    }

    @Test func aSaveThatMovesTheAudioReplacesTheFileAndKeepsItsAttributes() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let created = Date(timeIntervalSince1970: 978_307_200)
        try FileManager.default.setAttributes([.creationDate: created, .posixPermissions: 0o640], ofItemAtPath: url.path)
        #expect(setxattr(url.path, "com.example.kept", "kept", 4, 0, 0) == 0)
        let frames = try AVAudioFile(forReading: url).length
        let before = inode(url)

        try await saveArtwork(to: url)

        #expect(inode(url) != before)

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect(attributes[.creationDate] as? Date == created)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o640)
        #expect(getxattr(url.path, "com.example.kept", nil, 0, 0, 0) == 4)

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Replaced")
        #expect(reread.imageDescription.cgImage != nil)
        #expect(try AVAudioFile(forReading: url).length == frames)

        let leftovers = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
            .filter { $0.hasSuffix(".save") }
        #expect(leftovers.isEmpty)
    }

    @Test func aSaveThatFitsInPlaceKeepsTheFile() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        try await saveArtwork(to: url)
        let before = inode(url)

        var description = try await MetaAudioFileDescription(parsing: url)
        description.tagProperties[.title] = "Fits"
        try description.save(dirtyFlags: [.tags])

        #expect(inode(url) == before)
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "Fits")
    }

    /// A swap would leave the other link on the old content.
    @Test func aHardLinkedFileIsSavedInPlace() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let link = url.deletingLastPathComponent().appendingPathComponent("link.mp3")
        try FileManager.default.linkItem(at: url, to: link)
        let before = inode(url)

        try await saveArtwork(to: url)

        #expect(inode(url) == before)
        #expect(try await MetaAudioFileDescription(parsing: link).tagProperties[.title] == "Replaced")
    }

    #if os(macOS)
    /// A disk image formatted `fileSystem` (an `hdiutil -fs` name), attached for `body`.
    private func withVolume(_ fileSystem: String, _ body: (URL) async throws -> Void) async throws {
        let image = bin.appendingPathComponent("volume-\(UUID().uuidString).dmg")
        let mount = bin.appendingPathComponent("volume-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)

        try Self.run("/usr/bin/hdiutil", ["create", "-size", "20m", "-fs", fileSystem, "-volname", "SAVETEST", image.path])
        try Self.run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-mountpoint", mount.path, image.path])
        defer { try? Self.run("/usr/bin/hdiutil", ["detach", "-force", mount.path]) }

        try await body(mount)
    }

    /// The file systems an external drive is usually formatted with carry the file's attributes
    /// across the swap.
    @Test(.tags(.slow), .serialized, arguments: ["HFS+", "ExFAT"])
    func aFileOnAnExternalFileSystemIsReplaced(fileSystem: String) async throws {
        try await withVolume(fileSystem) { mount in
            let url = mount.appendingPathComponent("tabla.mp3")
            try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_mp3, to: url)
            #expect(setxattr(url.path, "com.example.kept", "kept", 4, 0, 0) == 0)
            let before = inode(url)

            try await saveArtwork(to: url)

            #expect(inode(url) != before)
            #expect(getxattr(url.path, "com.example.kept", nil, 0, 0, 0) == 4)
            #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "Replaced")
        }
    }

    /// A file system not known to carry the attributes is saved in place.
    @Test(.tags(.slow)) func aFileOnAnUnlistedFileSystemIsSavedInPlace() async throws {
        try await withVolume("UDF") { mount in
            let url = mount.appendingPathComponent("tabla.mp3")
            try FileManager.default.copyItem(at: TestBundleResources.shared.tabla_mp3, to: url)
            let before = inode(url)

            try await saveArtwork(to: url)

            #expect(inode(url) == before)
            #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "Replaced")
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableLoad) }
    }
    #endif

    @Test func aFileInAReadOnlyFolderIsSavedInPlace() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let folder = url.deletingLastPathComponent()
        let before = inode(url)

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }

        try await saveArtwork(to: url)

        #expect(inode(url) == before)
        #expect(try await MetaAudioFileDescription(parsing: url).tagProperties[.title] == "Replaced")
    }
}
