// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-metadata",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "SPFKMetadata",
            targets: ["SPFKMetadata", "SPFKMetadataC"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-taglib", from: "1.5.0"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-audio-base", from: "1.6.1"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-filesystem", from: "1.2.2"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-matroska", from: "1.0.0"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-metadata-base", from: "1.5.0"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "1.1.0"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-utils", from: "1.6.1"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-video", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "SPFKMetadata",
            dependencies: [
                .targetItem(name: "SPFKMetadataC", condition: nil),
                .product(name: "SPFKAudioBase", package: "spfk-audio-base"),
                .product(name: "SPFKFileSystem", package: "spfk-filesystem"),
                .product(name: "SPFKMatroska", package: "spfk-matroska"),
                .product(name: "SPFKMetadataBase", package: "spfk-metadata-base"),
                .product(name: "SPFKUtils", package: "spfk-utils"),
                .product(name: "SPFKVideo", package: "spfk-video"),
            ]
        ),
        .target(
            name: "SPFKMetadataC",
            dependencies: [
                .product(name: "taglib", package: "spfk-taglib"),
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
                .product(name: "SPFKVideo", package: "spfk-video"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-strict-concurrency=complete"]),
            ],
        ),
    ],
    cxxLanguageStandard: .cxx20
)
