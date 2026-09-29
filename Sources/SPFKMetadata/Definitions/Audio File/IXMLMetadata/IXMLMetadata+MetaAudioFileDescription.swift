// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata

@preconcurrency import AEXML
import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadataBase

extension IXMLMetadata {
    /// Fills SPEED, TRACK_LIST, BEXT, LOUDNESS and HISTORY from the file's format, tags and BEXT.
    public init(from description: MetaAudioFileDescription) {
        self.init()

        version = "1.52"
        project = description.tag(for: .album)
        note = description.tag(for: .comment)

        if let format = description.audioFormat {
            fileSampleRate = "\(Int(format.sampleRate))"

            if let bits = format.bitsPerChannel {
                audioBitDepth = "\(bits)"
            }

            if format.channelCount > 0 {
                tracks = (1 ... Int(format.channelCount)).map {
                    Track(channelIndex: "\($0)", interleaveIndex: "\($0)")
                }
            }
        }

        if let bext = description.bextDescription {
            bextVersion = "\(bext.version)"
            bextDescriptionText = bext.sequenceDescription
            bextOriginator = bext.originator
            bextOriginatorReference = bext.originatorReference
            bextOriginationDate = bext.originationDate
            bextOriginationTime = bext.originationTime

            if let value = bext.timeReferenceLow {
                bextTimeReferenceLow = "\(value)"
            }
            if let value = bext.timeReferenceHigh {
                bextTimeReferenceHigh = "\(value)"
            }

            bextCodingHistory = bext.codingHistory
            bextUMID = bext.umid

            // BEXT v2 carries loudness.
            let loudness = bext.loudnessDescription.validated()
            if loudness.isValid {
                loudnessDescription = loudness
            }
        }

        originalFilename = description.url.lastPathComponent
    }
}
