// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

import Foundation
import SPFKMetadataBase
internal import SPFKMetadataC

extension TagProperties {
    /// A WAV's tags read without its other components; nil when the file can't be opened.
    init?(waveTagsAt url: URL) {
        let waveFile = WaveFileC(path: url.path)
        guard waveFile.loadTags() else { return nil }

        self.init()

        if let value = waveFile.audioPropertiesC {
            audioProperties = AudioFormatProperties(cObject: value)
        }

        load(waveFile: waveFile)
    }

    /// INFO, then the ID3 tag over it, so ID3 wins where both hold a key. An INFO ID no key names
    /// is read as a custom tag under that ID, which a save writes back to it.
    mutating func load(waveFile: WaveFileC) {
        for (id, value) in waveFile.infoDictionary as? [String: String] ?? [:] {
            if let key = InfoFrameKey(value: id) {
                data.set(infoFrame: key, value: value)
            } else {
                data.set(taglibKey: id, value: value)
            }
        }

        for (key, value) in waveFile.id3Properties as? [String: String] ?? [:] {
            data.set(taglibKey: key, value: value)
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
        guard let stored = TagProperties(waveTagsAt: URL(fileURLWithPath: path)) else {
            setTags(tags)
            return
        }

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
    func setTags(_ tags: TagProperties) {
        tagsNeedsSave = true
        id3Properties = NSMutableDictionary(dictionary: tags.tagLibPropertyMap)
        infoDictionary = NSMutableDictionary(dictionary: tags.infoMirror)
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
