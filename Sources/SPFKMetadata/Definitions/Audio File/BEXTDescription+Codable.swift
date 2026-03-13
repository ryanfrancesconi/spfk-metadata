import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKUtils

extension BEXTDescription: Codable {
    enum CodingKeys: String, CodingKey {
        case codingHistory
        case loudnessDescription
        case originationDate
        case originationTime
        case originator
        case originatorReference
        case sampleRate
        case sequenceDescription
        case timeReferenceHigh
        case timeReferenceLow
        case umid
        case version
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decodeIfPresent(Int16.self, forKey: .version) ?? 0

        sequenceDescription = try? container.decodeIfPresent(String.self, forKey: .sequenceDescription)
        codingHistory = try? container.decodeIfPresent(String.self, forKey: .codingHistory)
        originator = try? container.decodeIfPresent(String.self, forKey: .originator)
        originationDate = try? container.decodeIfPresent(String.self, forKey: .originationDate)
        originationTime = try? container.decodeIfPresent(String.self, forKey: .originationTime)
        originatorReference = try? container.decodeIfPresent(String.self, forKey: .originatorReference)
        timeReferenceLow = try? container.decodeIfPresent(UInt64.self, forKey: .timeReferenceLow)
        timeReferenceHigh = try? container.decodeIfPresent(UInt64.self, forKey: .timeReferenceHigh)
        sampleRate = try? container.decodeIfPresent(Double.self, forKey: .sampleRate)

        if version >= 1 {
            umid = try? container.decodeIfPresent(String.self, forKey: .umid)
        }

        if version >= 2, let value = try? container.decodeIfPresent(LoudnessDescription.self, forKey: .loudnessDescription) {
            loudnessDescription = value
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(version, forKey: .version)
        try? container.encodeIfPresent(sequenceDescription, forKey: .sequenceDescription)
        try? container.encodeIfPresent(codingHistory, forKey: .codingHistory)
        try? container.encodeIfPresent(originator, forKey: .originator)
        try? container.encodeIfPresent(originationDate, forKey: .originationDate)
        try? container.encodeIfPresent(originationTime, forKey: .originationTime)
        try? container.encodeIfPresent(originatorReference, forKey: .originatorReference)
        try? container.encodeIfPresent(timeReferenceLow, forKey: .timeReferenceLow)
        try? container.encodeIfPresent(timeReferenceHigh, forKey: .timeReferenceHigh)
        try? container.encodeIfPresent(sampleRate, forKey: .sampleRate)

        if version >= 1 {
            try? container.encodeIfPresent(umid, forKey: .umid)
        }

        if version >= 2 {
            try? container.encodeIfPresent(loudnessDescription, forKey: .loudnessDescription)
        }
    }
}

extension BEXTDescription: Serializable {}
