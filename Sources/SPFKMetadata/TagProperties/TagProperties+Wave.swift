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
    /// extending the ID3 one (`2026-01-22` over `2026`) is kept. An INFO ID no ``TagKey`` maps is
    /// returned among the fields rather than read as a tag, with the DISP chunk's text.
    @discardableResult
    mutating func load(waveFile: WaveFileC) -> RIFFInfoFields {
        var fields = RIFFInfoFields()
        fields.displayText = DISPChunk.displayText(in: waveFile.dispPayloads.compactMap(DISPChunk.init(payload:)))

        for (id, value) in waveFile.infoDictionary as? [String: String] ?? [:] {
            if let key = InfoFrameKey(value: id), TagKey(infoFrame: key) != nil {
                data.set(infoFrame: key, value: value)
            } else {
                fields.set(field: id, value: value)
            }
        }

        let infoDate = data.tags[.date]
        let infoTitle = data.tags[.title]

        for (key, value) in waveFile.id3Properties as? [String: String] ?? [:] {
            data.set(taglibKey: key, value: value)
        }

        if let infoDate, let date = data.tags[.date], infoDate.extends(date) {
            data.tags[.date] = infoDate
        }

        if let infoTitle, infoTitle.isNotEmpty, infoTitle != data.tags[.title] {
            fields.infoTitle = infoTitle
        }

        return fields
    }

    /// The tags with an INFO field, keyed by its ID.
    var infoMirror: [String: String] {
        var mirror: [String: String] = [:]

        for (key, value) in tags {
            if let frame = key.infoFrame { mirror[frame.value] = value }
        }

        return mirror
    }

    /// The INFO writes that take the file's mapped fields from `stored` to these tags: each tag
    /// that differs writes its primary field and removes its alternates, and an absent tag
    /// removes its field. Every other mapped field is left as the file has it.
    func infoChanges(from stored: TagProperties) -> [String: String] {
        var info: [String: String] = [:]

        for key in TagKey.allCases {
            guard let frame = key.infoFrame, tags[key] != stored.tags[key] else { continue }

            for alternate in key.infoAlternates {
                info[alternate.value] = ""
            }

            info[frame.value] = tags[key] ?? ""
        }

        return info
    }

    /// Without each custom tag that an older read made of an INFO field in `fields`, unless the
    /// file also holds it in ID3 (`storedID3`, keyed as `WaveFileC.id3Properties` is).
    func removingCustomTags(namingFieldsIn fields: RIFFInfoFields, storedID3: [String: String]) -> TagProperties {
        var properties = self

        for key in customTags.keys where storedID3[key.uppercased()] == nil {
            if fields.fields.keys.contains(where: { RIFFInfoFields.customTag(key, names: $0) }) {
                properties.customTags[key] = nil
            }
        }

        return properties
    }
}

extension RIFFInfoFields {
    /// The INFO writes that take the file's `stored` fields to these: a changed or added field set,
    /// a missing one removed.
    func infoChanges(from stored: RIFFInfoFields) -> [String: String] {
        var info: [String: String] = [:]

        for (id, value) in fields where stored.fields[id] != value {
            info[id] = value
        }

        for id in stored.fields.keys where fields[id] == nil {
            info[id] = ""
        }

        return info
    }
}

extension WaveFileC {
    /// What a save of `tags` and `infoFields` writes over the file's: each tag and INFO field
    /// that differs when any text does, the rating alone when only it does, nothing otherwise.
    /// Every tag and field when the file's can't be read.
    func setTagChanges(_ tags: TagProperties, infoFields: RIFFInfoFields? = nil) {
        let stored = WaveFileC(path: path)

        guard stored.loadTags() else {
            setTags(tags, infoFields: infoFields)
            return
        }

        setTagChanges(tags, infoFields: infoFields, storedIn: stored)
    }

    /// `setTagChanges(_:infoFields:)` against a `loadTags()` of the file.
    ///
    /// With nil `infoFields`, every unmapped INFO field is left as the file has it, and a custom
    /// tag an older read made of one is not written to ID3.
    func setTagChanges(_ tags: TagProperties, infoFields: RIFFInfoFields?, storedIn file: WaveFileC) {
        var stored = TagProperties()
        let storedFields = stored.load(waveFile: file)
        let storedID3 = file.id3Properties as? [String: String] ?? [:]

        let tags = infoFields == nil ? tags.removingCustomTags(namingFieldsIn: storedFields, storedID3: storedID3) : tags
        let fieldChanges = infoFields?.infoChanges(from: storedFields) ?? [:]

        var storedText = stored.data
        var text = tags.data
        storedText.tags[.rating] = nil
        text.tags[.rating] = nil

        if storedText != text || fieldChanges.isNotEmpty {
            tagsNeedsSave = true
            id3Properties = NSMutableDictionary(dictionary: tags.tagLibPropertyMap)
            infoDictionary = NSMutableDictionary(dictionary: tags.infoChanges(from: stored).merging(fieldChanges) { $1 })
        } else if stored[.rating] != tags[.rating] {
            setRating(tags)
        } else {
            tagsNeedsSave = false
        }
    }

    /// `tags` as the ID3 properties, and the INFO mirror plus `infoFields` as the fields set over
    /// the file's, for a save with no stored file to compare against.
    func setTags(_ tags: TagProperties, infoFields: RIFFInfoFields? = nil) {
        tagsNeedsSave = true
        id3Properties = NSMutableDictionary(dictionary: tags.tagLibPropertyMap)
        infoDictionary = NSMutableDictionary(dictionary: tags.infoMirror.merging(infoFields?.fields ?? [:]) { $1 })
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
