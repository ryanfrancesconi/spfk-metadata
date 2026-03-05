// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation

/// Protocol for ID3 and RIFF INFO frame key enums, providing default implementations
/// for ``taglibKey``, ``displayName``, and initializers from raw values and display names.
///
/// Adopted by ``ID3FrameKey`` and ``InfoFrameKey``.
public protocol TagFrameKey: CaseIterable, RawRepresentable where RawValue == String {
    /// The frame identifier string (e.g., "TIT2" for ID3, "INAM" for INFO).
    var value: String { get }
}

extension TagFrameKey {
    /// The uppercase key used by TagLib's property map.
    public var taglibKey: String {
        rawValue.uppercased()
    }

    /// Human-readable title-cased name derived from the raw value.
    public var displayName: String {
        rawValue.spacedTitleCased
    }

    /// Creates a frame key from its frame identifier string (e.g., "TIT2").
    public init?(value: String) {
        for item in Self.allCases where item.value == value {
            self = item
            return
        }

        return nil
    }

    /// Creates a frame key from its human-readable display name.
    public init?(displayName: String) {
        for item in Self.allCases where item.displayName == displayName {
            self = item
            return
        }

        return nil
    }

    /// Creates a frame key from its TagLib property map key.
    public init?(taglibKey: String) {
        for item in Self.allCases where item.taglibKey == taglibKey {
            self = item
            return
        }
        return nil
    }
}
