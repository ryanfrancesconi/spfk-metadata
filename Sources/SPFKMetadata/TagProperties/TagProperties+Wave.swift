// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension TagProperties {
    /// The tags of a `WaveFileC` already loaded.
    init(waveFile: WaveFileC) {
        self.init()

        if let value = waveFile.audioPropertiesC {
            audioProperties = AudioFormatProperties(cObject: value)
        }

        load(waveFile: waveFile)
    }

    /// INFO, then the ID3 tag over it, so ID3 wins where both hold a key, except that an INFO date
    /// extending the ID3 one (`2026-01-22` over `2026`) is kept. An INFO ID no key names is read
    /// as a custom tag under that ID, which a save writes back to it. An ID with a lowercase letter
    /// is skipped: custom tags are uppercased into ID3, where it would collide with its uppercase
    /// twin, and a save leaves it on disk as it is.
    mutating func load(waveFile: WaveFileC) {
        for (id, value) in waveFile.infoDictionary as? [String: String] ?? [:] {
            guard !id.contains(where: { $0.isASCII && $0.isLowercase }) else { continue }

            if let key = InfoFrameKey(value: id) {
                data.set(infoFrame: key, value: value)
            } else {
                data.set(taglibKey: id, value: value)
            }
        }

        let infoDate = data.tags[.date]

        for (key, value) in waveFile.id3Properties as? [String: String] ?? [:] {
            data.set(taglibKey: key, value: value)
        }

        if let infoDate, let date = data.tags[.date], infoDate.extends(date) {
            data.tags[.date] = infoDate
        }
    }

    /// The tags with an INFO field, keyed by its ID. A standard tag wins over a custom one.
    var infoMirror: [String: String] {
        var mirror: [String: String] = [:]

        for (key, value) in tags {
            if let frame = key.infoFrame { mirror[frame.value] = value }
        }

        for (key, value) in customTags {
            guard let frame = InfoFrameKey(taglibKey: key.uppercased()), mirror[frame.value] == nil else { continue }
            mirror[frame.value] = value
        }

        return mirror
    }
}

extension WaveFileC {
    /// What a save of `tags` writes over the file's tags: every tag when a text tag differs, the
    /// rating alone when only it does, nothing otherwise. Every tag when the file's can't be read.
    func setTagChanges(_ tags: TagProperties) {
        let stored = WaveFileC(path: path)

        guard stored.loadTags() else {
            setTags(tags)
            return
        }

        setTagChanges(tags, storedIn: stored)
    }

    /// `setTagChanges(_:)` against a `loadTags()` of the file.
    func setTagChanges(_ tags: TagProperties, storedIn file: WaveFileC) {
        let stored = TagProperties(waveFile: file)

        var storedText = stored.data
        var text = tags.data
        storedText.tags[.rating] = nil
        text.tags[.rating] = nil

        if storedText != text {
            setTags(tags)
        } else if stored[.rating] != tags[.rating] {
            setRating(tags)
        } else {
            tagsNeedsSave = false
        }
    }

    /// `tags` as the ID3 properties and the INFO mirror a full tag save writes.
    ///
    /// A named INFO ID missing from the mirror is written empty, which removes it, so the save
    /// never keeps it from an ID3 key spelled the same: `ISRC` is INFO Source and ``TagKey/isrc``.
    func setTags(_ tags: TagProperties) {
        let id3 = tags.tagLibPropertyMap
        var info = tags.infoMirror

        for frame in InfoFrameKey.allCases where info[frame.value] == nil && id3[frame.value] != nil {
            info[frame.value] = ""
        }

        tagsNeedsSave = true
        id3Properties = NSMutableDictionary(dictionary: id3)
        infoDictionary = NSMutableDictionary(dictionary: info)
    }

    /// `tags`' rating alone.
    func setRating(_ tags: TagProperties) {
        tagsNeedsSave = false
        ratingNeedsSave = true

        let rating = tags[.rating]
        id3Properties = NSMutableDictionary(dictionary: rating.map { [TagKey.rating.taglibKey: $0] } ?? [:])

        if let frame = TagKey.rating.infoFrame {
            infoDictionary = NSMutableDictionary(dictionary: [frame.value: rating ?? ""])
        }
    }
}

extension String {
    /// Longer than `other` and starting with it: `2026-01-22` extends `2026`.
    func extends(_ other: String) -> Bool {
        count > other.count && hasPrefix(other)
    }
}
