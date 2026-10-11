import Foundation

public struct LiveCaption: Identifiable, Equatable, Sendable {
    public let id: Int
    public var start: Double
    public var end: Double
    public var text: String
    public var isFinal: Bool
    public var translation: String?
}

/// Speech results revise time ranges; finalization can also confirm earlier results.
public struct LiveTranscript: Sendable {
    public private(set) var captions: [LiveCaption] = []
    private var nextID = 0
    public init() {}

    public mutating func update(text: String, start: Double, end: Double,
                                isFinal: Bool, finalizedThrough: Double) {
        guard start.isFinite, end.isFinite, end > start, start >= 0 else { return }
        let overlapping = captions.filter { $0.start < end - 0.001 && $0.end > start + 0.001 }
        let same = overlapping.first { abs($0.start - start) < 0.02 }
        captions.removeAll { $0.start < end - 0.001 && $0.end > start + 0.001 }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            let id = same?.id ?? nextID
            if same == nil { nextID += 1 }
            captions.append(LiveCaption(id: id, start: start, end: end, text: clean,
                isFinal: isFinal, translation: same?.text == clean ? same?.translation : nil))
        }
        if finalizedThrough.isFinite {
            for i in captions.indices where captions[i].end <= finalizedThrough + 0.001 {
                captions[i].isFinal = true
            }
        }
        captions.sort { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }

    public mutating func translate(id: Int, source: String, text: String) {
        guard let i = captions.firstIndex(where: { $0.id == id && $0.text == source }) else { return }
        captions[i].translation = text
    }

    public var track: SubtitleTrack {
        SubtitleTrack(cues: captions.map { SubtitleCue(id: $0.id, start: $0.start, end: $0.end, text: $0.text) })
    }
}
