// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension MetaAudioFileDescription {
    /// Version 1 reads WAV INFO text that isn't valid UTF-8 as Latin-1, where earlier reads
    /// returned it empty, and keeps an INFO date that extends the ID3 one, where earlier reads
    /// kept the ID3 year.
    public static let currentTagReaderVersion = 1

    /// Whether these are a WAV's tags read by an older reader and hold a value it may have read
    /// as empty, or a date it may have read short.
    public var hasStaleTagRead: Bool {
        guard fileType == .wav, (tagReaderVersion ?? 0) < Self.currentTagReaderVersion else { return false }
        return tagProperties.tags[.date] != nil || tagProperties.tags.values.contains("")
            || tagProperties.customTags.values.contains("")
    }

    /// Fills each tag held empty with the file's value and replaces a held date the file's
    /// extends, leaving every other value alone, and stamps ``tagReaderVersion``. False, changing
    /// nothing, when the file can't be read.
    public mutating func refreshStaleTagRead() -> Bool {
        let waveFile = WaveFileC(path: url.path)
        guard url.exists, waveFile.loadTags() else { return false }

        let read = TagProperties(waveFile: waveFile)

        for (key, value) in tagProperties.tags where value.isEmpty {
            if let stored = read.tags[key], !stored.isEmpty { tagProperties.tags[key] = stored }
        }

        for (key, value) in tagProperties.customTags where value.isEmpty {
            if let stored = read.customTags[key], !stored.isEmpty { tagProperties.customTags[key] = stored }
        }

        if let date = tagProperties.tags[.date], let stored = read.tags[.date], stored.extends(date) {
            tagProperties.tags[.date] = stored
        }

        tagReaderVersion = Self.currentTagReaderVersion
        return true
    }

    /// Whether ``refreshStaleTagRead()`` would change a value, for a description whose pending
    /// edit it must not touch; nil when there is nothing stale or the file can't be read. Reads
    /// the file; changes nothing.
    public func staleTagReadRecoversText() -> Bool? {
        guard hasStaleTagRead else { return nil }

        var refreshed = self
        guard refreshed.refreshStaleTagRead() else { return nil }
        return refreshed.tagProperties.data != tagProperties.data
    }
}
