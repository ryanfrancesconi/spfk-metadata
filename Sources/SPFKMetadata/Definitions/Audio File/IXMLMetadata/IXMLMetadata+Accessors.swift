// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation

// MARK: - Descriptor-based read/write

extension IXMLMetadata {
    /// Returns the current string value for the given descriptor, or `nil` if not set.
    public func value(for descriptor: IXMLTagDescriptor) -> String? {
        switch descriptor.section {
        case .core:
            return coreValue(xmlTag: descriptor.xmlTag)
        case .user:
            guard let fields = userFields,
                  let entry = iXMLUserFieldMap.first(where: { $0.xmlName == descriptor.xmlTag })
            else { return nil }
            return fields[keyPath: entry.keyPath]
        case .aswg:
            guard let fields = aswgFields,
                  let entry = iXMLASWGFieldMap.first(where: { $0.xmlName == descriptor.xmlTag })
            else { return nil }
            return fields[keyPath: entry.keyPath]
        case .bext:
            return bextValue(xmlTag: descriptor.xmlTag)
        case .speed:
            return speedValue(xmlTag: descriptor.xmlTag)
        case .history:
            return historyValue(xmlTag: descriptor.xmlTag)
        case .location:
            return locationValue(xmlTag: descriptor.xmlTag)
        case .loudness:
            return loudnessValue(xmlTag: descriptor.xmlTag)
        }
    }

    /// Sets the string value for the given descriptor.
    ///
    /// No-ops if the descriptor is read-only or the xmlTag is unrecognized.
    public mutating func setValue(_ value: String?, for descriptor: IXMLTagDescriptor) {
        guard !descriptor.isReadOnly else { return }

        switch descriptor.section {
        case .core:
            setCoreValue(value, xmlTag: descriptor.xmlTag)
        case .user:
            guard let entry = iXMLUserFieldMap.first(where: { $0.xmlName == descriptor.xmlTag }) else { return }
            var fields = userFields ?? IXMLUserFields()
            fields[keyPath: entry.keyPath] = value
            setUserFields(fields)
        case .aswg:
            guard let entry = iXMLASWGFieldMap.first(where: { $0.xmlName == descriptor.xmlTag }) else { return }
            var fields = aswgFields ?? IXMLASWGFields()
            fields[keyPath: entry.keyPath] = value
            setASWGFields(fields)
        case .location:
            setLocationValue(value, xmlTag: descriptor.xmlTag)
        case .bext, .speed, .history, .loudness:
            break
        }
    }
}

// MARK: - Private section helpers

extension IXMLMetadata {
    private func coreValue(xmlTag: String) -> String? {
        switch xmlTag {
        case "PROJECT":      return project
        case "SCENE":        return scene
        case "TAKE":         return take
        case "TAPE":         return tape
        case "NOTE":         return note
        case "CIRCLED":      return circled
        case "WILD_TRACK":   return wildTrack
        case "FAMILY_NAME":  return familyName
        case "FAMILY_UID":   return familyUID
        case "FILE_UID":     return fileUID
        case "IXML_VERSION": return version
        default:             return nil
        }
    }

    private mutating func setCoreValue(_ value: String?, xmlTag: String) {
        switch xmlTag {
        case "PROJECT":     project = value
        case "SCENE":       scene = value
        case "TAKE":        take = value
        case "TAPE":        tape = value
        case "NOTE":        note = value
        case "CIRCLED":     circled = value
        case "WILD_TRACK":  wildTrack = value
        case "FAMILY_NAME": familyName = value
        default:            break
        }
    }

    private func bextValue(xmlTag: String) -> String? {
        switch xmlTag {
        case "BWF_DESCRIPTION":         return bextDescriptionText
        case "BWF_ORIGINATOR":          return bextOriginator
        case "BWF_ORIGINATOR_REFERENCE":return bextOriginatorReference
        case "BWF_ORIGINATION_DATE":    return bextOriginationDate
        case "BWF_ORIGINATION_TIME":    return bextOriginationTime
        case "BWF_UMID":                return bextUMID
        case "BWF_CODING_HISTORY":      return bextCodingHistory
        case "BWF_VERSION":             return bextVersion
        default:                        return nil
        }
    }

    private func speedValue(xmlTag: String) -> String? {
        switch xmlTag {
        case "FILE_SAMPLE_RATE":  return fileSampleRate
        case "AUDIO_BIT_DEPTH":   return audioBitDepth
        case "TIMECODE_RATE":     return timecodeRate
        case "TIMECODE_FLAG":     return timecodeFlag
        case "MASTER_SPEED":      return masterSpeed
        case "CURRENT_SPEED":     return currentSpeed
        default:                  return nil
        }
    }

    private func historyValue(xmlTag: String) -> String? {
        switch xmlTag {
        case "ORIGINAL_FILENAME": return originalFilename
        case "PARENT_FILENAME":   return parentFilename
        case "PARENT_UID":        return parentUID
        default:                  return nil
        }
    }

    private func locationValue(xmlTag: String) -> String? {
        switch xmlTag {
        case "GPS":      return locationGPS
        case "ALTITUDE": return locationAltitude
        case "TIME":     return locationTime
        default:         return nil
        }
    }

    private mutating func setLocationValue(_ value: String?, xmlTag: String) {
        switch xmlTag {
        case "GPS":      locationGPS = value
        case "ALTITUDE": locationAltitude = value
        case "TIME":     locationTime = value
        default:         break
        }
    }

    private func loudnessValue(xmlTag: String) -> String? {
        guard let loudness = loudnessDescription else { return nil }
        switch xmlTag {
        case "LOUDNESS_VALUE":
            return loudness.loudnessIntegrated.map { String(format: "%.2f", $0) }
        case "LOUDNESS_RANGE":
            return loudness.loudnessRange.map { String(format: "%.2f", $0) }
        case "MAX_TRUE_PEAK_LEVEL":
            return loudness.maxTruePeakLevel.map { String(format: "%.2f", $0) }
        case "MAX_MOMENTARY":
            return loudness.maxMomentaryLoudness.map { String(format: "%.2f", $0) }
        case "MAX_SHORT_TERM":
            return loudness.maxShortTermLoudness.map { String(format: "%.2f", $0) }
        default:
            return nil
        }
    }
}
