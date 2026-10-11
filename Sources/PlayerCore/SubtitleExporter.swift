import Foundation

/// Exports the visible text of two independent tracks without changing either track.
public enum SubtitleExporter {
    public struct Output: Sendable {
        public let text: String
        public let cueCount: Int
    }

    public enum ExportError: BilingualError, Equatable, Sendable {
        case invalidOffset, invalidTime, timeOutOfRange, submillisecondCue, noContent

        public var message: LocalizedText {
            switch self {
            case .invalidOffset: return LocalizedText("The subtitle offset is invalid or too large. Adjust it before exporting.", "字幕时间偏移无效或过大，请调整后再导出。")
            case .invalidTime: return LocalizedText("The subtitles contain invalid timestamps and cannot be exported.", "字幕包含无效时间，无法导出。")
            case .timeOutOfRange: return LocalizedText("A subtitle timestamp exceeds the export limit of 9999:59:59,999.", "字幕时间超出可导出范围（最长 9999:59:59,999）。")
            case .submillisecondCue: return LocalizedText("A subtitle has no duration after rounding to milliseconds. Adjust its timestamps before exporting.", "有字幕在毫秒舍入后没有时长，请调整时间后再导出。")
            case .noContent: return LocalizedText("There is no subtitle text to export. Check the content and time offsets.", "没有可导出的字幕文字；请检查字幕内容和时间偏移。")
            }
        }
    }

    // Explicitly bounded before floating-point-to-integer conversion. Supports >99-hour SRTs.
    private static let maximumMilliseconds: Int64 = 35_999_999_999
    private static var maximumSeconds: Double { Double(maximumMilliseconds) / 1000 }

    private struct TimedText {
        let start: Int64
        let end: Int64
        let text: String
    }

    private struct Event {
        let time: Int64
        let index: Int
        let begins: Bool
    }

    private struct Segment {
        let start: Int64
        var end: Int64
        let text: String
    }

    /// Applies each offset once, clips at zero, and rounds boundaries to the nearest millisecond.
    /// Every active primary cue precedes every active secondary cue; overlaps are retained.
    /// Empty text and intervals wholly before zero are omitted. Positive intervals that collapse
    /// at millisecond precision throw rather than silently losing their text.
    public static func srt(primary: SubtitleTrack, secondary: SubtitleTrack,
                           primaryOffset: Double = 0, secondaryOffset: Double = 0) throws -> Output {
        guard primaryOffset.isFinite, secondaryOffset.isFinite,
              abs(primaryOffset) <= maximumSeconds, abs(secondaryOffset) <= maximumSeconds else {
            throw ExportError.invalidOffset
        }
        let cues = try prepare(primary, offset: primaryOffset) + prepare(secondary, offset: secondaryOffset)
        guard !cues.isEmpty else { throw ExportError.noContent }
        var events: [Event] = []
        for (index, cue) in cues.enumerated() {
            events.append(Event(time: cue.start, index: index, begins: true))
            events.append(Event(time: cue.end, index: index, begins: false))
        }
        events.sort { $0.time < $1.time }
        var active: Set<Int> = []
        var segments: [Segment] = []
        var cursor = 0
        while cursor < events.count {
            let time = events[cursor].time
            // All changes at a boundary take effect together: intervals are [start, end).
            while cursor < events.count, events[cursor].time == time {
                let event = events[cursor]
                if event.begins { active.insert(event.index) }
                else { active.remove(event.index) }
                cursor += 1
            }
            guard cursor < events.count, !active.isEmpty else { continue }
            let end = events[cursor].time
            // Prepared indices retain each track's stable cue order, with primary first.
            let text = active.sorted().map { cues[$0].text }.joined(separator: "\n")
            if let last = segments.last, last.end == time, last.text == text {
                segments[segments.count - 1].end = end
            } else {
                segments.append(Segment(start: time, end: end, text: text))
            }
        }
        guard !segments.isEmpty else { throw ExportError.noContent }
        let blocks = segments.enumerated().map { index, segment in
            "\(index + 1)\n\(timestamp(segment.start)) --> \(timestamp(segment.end))\n\(encodeText(segment.text))"
        }
        return Output(text: blocks.joined(separator: "\n\n") + "\n", cueCount: segments.count)
    }

    private static func prepare(_ track: SubtitleTrack, offset: Double) throws -> [TimedText] {
        var result: [TimedText] = []
        for cue in track.cues {
            guard cue.start.isFinite, cue.end.isFinite, cue.start >= 0, cue.end > cue.start else {
                throw ExportError.invalidTime
            }
            guard cue.end <= maximumSeconds else { throw ExportError.timeOutOfRange }
            let text = cue.text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let shiftedStart = cue.start + offset
            let shiftedEnd = cue.end + offset
            guard shiftedStart.isFinite, shiftedEnd.isFinite,
                  shiftedStart <= maximumSeconds, shiftedEnd <= maximumSeconds else {
                throw ExportError.timeOutOfRange
            }
            guard shiftedEnd > 0 else { continue }
            let start = try milliseconds(max(0, shiftedStart))
            let end = try milliseconds(shiftedEnd)
            guard end > start else { throw ExportError.submillisecondCue }
            result.append(TimedText(start: start, end: end, text: text))
        }
        return result
    }

    private static func milliseconds(_ seconds: Double) throws -> Int64 {
        let rounded = (seconds * 1000).rounded(.toNearestOrAwayFromZero)
        guard rounded.isFinite, rounded >= 0, rounded <= Double(maximumMilliseconds) else {
            throw ExportError.timeOutOfRange
        }
        return Int64(rounded)
    }

    private static func timestamp(_ value: Int64) -> String {
        func pad(_ number: Int64, _ width: Int) -> String {
            let digits = String(number)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
        return "\(pad(value / 3_600_000, 2)):\(pad(value / 60_000 % 60, 2)):\(pad(value / 1000 % 60, 2)),\(pad(value % 1000, 3))"
    }

    /// Escape literal markup/entities and arrows so re-import cannot interpret text as SRT syntax.
    /// Internal empty lines become numeric newline entities, never blank SRT block delimiters.
    /// The parser decodes entities once, recovering the normalized text and paragraph spacing.
    private static func encodeText(_ text: String) -> String {
        func escape(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\u{FEFF}", with: "&#65279;")
        }
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.isEmpty {
                if !lines.isEmpty { lines[lines.count - 1] += "&#10;" }
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append(line.unicodeScalars.map { "&#\($0.value);" }.joined())
            } else {
                lines.append(escape(line))
            }
        }
        return lines.joined(separator: "\n")
    }
}
