// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-metadata",
    defaultLocalization: "en",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(
            name: "SPFKMetadata",
            targets: ["SPFKMetadata", "SPFKMetadataC"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/CXXTagLib", from: "2.1.3"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-audio-base", from: "0.0.4"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "0.0.4"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-utils", from: "0.0.8"),
        .package(url: "https://github.com/sbooth/sndfile-binary-xcframework", from: "0.1.2"),
        .package(url: "https://github.com/sbooth/ogg-binary-xcframework", from: "0.1.3"),
        .package(url: "https://github.com/sbooth/flac-binary-xcframework", from: "0.2.0"),
        .package(url: "https://github.com/sbooth/opus-binary-xcframework", from: "0.2.2"),
        .package(url: "https://github.com/sbooth/vorbis-binary-xcframework", from: "0.1.2"),
    ],
    targets: [
        .target(
            name: "SPFKMetadata",
            dependencies: [
                .targetItem(name: "SPFKMetadataC", condition: nil),
                .product(name: "SPFKAudioBase", package: "spfk-audio-base"),
                .product(name: "SPFKUtils", package: "spfk-utils"),
            ]
        ),
        .target(
            name: "SPFKMetadataC",
            dependencies: [
                .product(name: "taglib", package: "CXXTagLib"),
                .product(name: "sndfile", package: "sndfile-binary-xcframework"),
                .product(name: "ogg", package: "ogg-binary-xcframework"),
                .product(name: "FLAC", package: "flac-binary-xcframework"),
                .product(name: "opus", package: "opus-binary-xcframework"),
                .product(name: "vorbis", package: "vorbis-binary-xcframework"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include_private")
            ],
            cxxSettings: [
                .headerSearchPath("include_private")
            ]
        ),
        .testTarget(
            name: "SPFKMetadataTests",
            dependencies: [
                .targetItem(name: "SPFKMetadata", condition: nil),
                .targetItem(name: "SPFKMetadataC", condition: nil),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-strict-concurrency=complete"]),
            ],
        ),
    ],
    cxxLanguageStandard: .cxx20
)
