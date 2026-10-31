// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension MetaAudioFileDescription {
    /// Version 1 reads WAV INFO text that isn't valid UTF-8 as Latin-1, where earlier reads
    /// returned it empty, and keeps an INFO date that extends the ID3 one, where earlier reads
    /// kept the ID3 year.
    public static let currentTagReaderVersion = 1

    /// Whether these are a WAV's tags read by an older reader: one that may have read a value as
    /// empty or a date short, or one that read the INFO fields no tag maps as custom tags. Only a
    /// description holding a custom tag can be the second.
    public var hasStaleTagRead: Bool {
        guard fileType == .wav else { return false }
        return hasStaleTextRead || (riffInfoFields == nil && tagProperties.customTags.isNotEmpty)
    }

    private var hasStaleTextRead: Bool {
        guard (tagReaderVersion ?? 0) < Self.currentTagReaderVersion else { return false }
        return tagProperties.tags[.date] != nil || tagProperties.tags.values.contains("")
            || tagProperties.customTags.values.contains("")
    }

    /// Fills each tag held empty with the file's value and replaces a held date the file's
    /// extends, leaving every other value alone, and stamps ``tagReaderVersion``. Where
    /// ``riffInfoFields`` is nil, reads them and drops each custom tag the file holds as one of
    /// them rather than in ID3. False, changing nothing, when the file can't be read.
    public mutating func refreshStaleTagRead() -> Bool {
        let waveFile = WaveFileC(path: url.path)
        guard url.exists, waveFile.loadTags() else { return false }

        var read = TagProperties()
        let fields = read.load(waveFile: waveFile)

        recoverStaleText(from: read)

        if riffInfoFields == nil {
            let storedID3 = waveFile.id3Properties as? [String: String] ?? [:]
            tagProperties = tagProperties.removingCustomTags(namingFieldsIn: fields, storedID3: storedID3)
            riffInfoFields = fields
        }

        tagReaderVersion = Self.currentTagReaderVersion
        return true
    }

    private mutating func recoverStaleText(from read: TagProperties) {
        for (key, value) in tagProperties.tags where value.isEmpty {
            if let stored = read.tags[key], !stored.isEmpty { tagProperties.tags[key] = stored }
        }

        for (key, value) in tagProperties.customTags where value.isEmpty {
            if let stored = read.customTags[key], !stored.isEmpty { tagProperties.customTags[key] = stored }
        }

        if let date = tagProperties.tags[.date], let stored = read.tags[.date], stored.extends(date) {
            tagProperties.tags[.date] = stored
        }
    }

    /// Whether ``refreshStaleTagRead()`` would recover text, for a description whose pending edit
    /// it must not touch; nil when no text is stale or the file can't be read. Reads the file;
    /// changes nothing.
    public func staleTagReadRecoversText() -> Bool? {
        guard fileType == .wav, hasStaleTextRead else { return nil }

        let waveFile = WaveFileC(path: url.path)
        guard url.exists, waveFile.loadTags() else { return nil }

        var read = TagProperties()
        read.load(waveFile: waveFile)

        var refreshed = self
        refreshed.recoverStaleText(from: read)
        return refreshed.tagProperties.data != tagProperties.data
    }
}
