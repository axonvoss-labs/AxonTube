import Foundation

public struct SubtitleCue: Identifiable, Equatable, Sendable {
    public let id: Int
    public let start: Double
    public let end: Double
    public let text: String

    public init(id: Int, start: Double, end: Double, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}

/// A subtitle track has its own clock. All intervals are [start, end).
public struct SubtitleTrack: Sendable {
    public let cues: [SubtitleCue]
    private let prefixMaximumEnds: [Double]

    public init(cues: [SubtitleCue]) {
        self.cues = cues.enumerated()
            .filter { $0.element.start.isFinite && $0.element.end.isFinite && $0.element.start >= 0 && $0.element.end > $0.element.start }
            .sorted {
                if $0.element.start != $1.element.start { return $0.element.start < $1.element.start }
                if $0.element.end != $1.element.end { return $0.element.end < $1.element.end }
                return $0.offset < $1.offset
            }.map(\.element)
        var maximum = -Double.infinity
        self.prefixMaximumEnds = self.cues.map { cue in
            maximum = max(maximum, cue.end)
            return maximum
        }
    }

    public func activeCues(at time: Double) -> [SubtitleCue] {
        guard time.isFinite else { return [] }
        var index = firstStart(after: time) - 1
        var result: [SubtitleCue] = []
        // Looking only at the preceding cue loses an earlier, longer overlap.
        while index >= 0 && prefixMaximumEnds[index] > time {
            if cues[index].end > time { result.append(cues[index]) }
            index -= 1
        }
        return result.reversed()
    }

    /// Returns every cue with positive overlap against [start, end).
    public func overlappingCues(start: Double, end: Double) -> [SubtitleCue] {
        guard start.isFinite, end.isFinite, end > start else { return [] }
        var index = firstStart(after: end) - 1
        var result: [SubtitleCue] = []
        while index >= 0 && prefixMaximumEnds[index] > start {
            if cues[index].start < end && cues[index].end > start { result.append(cues[index]) }
            index -= 1
        }
        return result.reversed()
    }

    /// During overlaps, the most recently starting active cue is selected.
    public func activeIndex(at time: Double) -> Int? {
        guard time.isFinite else { return nil }
        var index = firstStart(after: time) - 1
        while index >= 0 && prefixMaximumEnds[index] > time {
            if cues[index].end > time { return index }
            index -= 1
        }
        return nil
    }

    /// Returns the last cue starting strictly before time. Mid-sentence, this restarts it.
    public func previousIndex(at time: Double) -> Int? {
        guard time.isFinite else { return nil }
        var low = 0
        var high = cues.count
        while low < high {
            let middle = low + (high - low) / 2
            if cues[middle].start < time { low = middle + 1 } else { high = middle }
        }
        return low > 0 ? low - 1 : nil
    }

    public func nextIndex(at time: Double) -> Int? {
        guard time.isFinite else { return nil }
        let index = firstStart(after: time)
        return index < cues.count ? index : nil
    }

    private func firstStart(after time: Double) -> Int {
        var low = 0
        var high = cues.count
        while low < high {
            let middle = low + (high - low) / 2
            if cues[middle].start <= time { low = middle + 1 } else { high = middle }
        }
        return low
    }
}

public enum SubtitleError: BilingualError, Equatable {
    case unsupportedFormat(String)
    case noValidCues(String)
    case unsupportedEncoding
    case nonLocalFile

    public var message: LocalizedText {
        switch self {
        case .unsupportedFormat(let fileExtension):
            return LocalizedText(".\(fileExtension) subtitles are not supported. Choose an SRT, VTT, ASS, or SSA file.", "不支持 .\(fileExtension) 字幕。请选择 SRT、VTT、ASS 或 SSA 文件。")
        case .noValidCues(let format):
            return LocalizedText("This \(format.uppercased()) file contains no usable timed text. Check the timestamps and ensure each end time is after its start time.", "这份 \(format.uppercased()) 字幕没有可用的时间轴和文字。请检查时间格式，以及结束时间是否晚于开始时间。")
        case .unsupportedEncoding:
            return LocalizedText("The subtitle encoding could not be read. Save it as UTF-8, UTF-16 with a BOM, or GB18030 and try again.", "无法读取字幕的文字编码。请将文件保存为 UTF-8、带 BOM 的 UTF-16 或 GB18030 后重试。")
        case .nonLocalFile:
            return LocalizedText("Choose a local subtitle file. This import action does not download subtitles.", "请选择本机上的字幕文件。此导入操作不会联网下载字幕。")
        }
    }
}

public enum SubtitleParser {
    public static func read(url: URL) throws -> [SubtitleCue] {
        guard url.isFileURL else { throw SubtitleError.nonLocalFile }
        let data = try Data(contentsOf: url)
        guard let text = decode(data) else { throw SubtitleError.unsupportedEncoding }
        return try parse(text, fileExtension: url.pathExtension)
    }

    public static func parse(_ text: String, fileExtension: String) throws -> [SubtitleCue] {
        let format = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        let normalized = text.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let raw: [SubtitleCue]
        switch format {
        case "srt", "vtt": raw = parseTimedText(normalized, isVTT: format == "vtt")
        case "ass", "ssa": raw = parseASS(normalized)
        default: throw SubtitleError.unsupportedFormat(format)
        }
        let sorted = raw.enumerated().sorted {
            if $0.element.start != $1.element.start { return $0.element.start < $1.element.start }
            if $0.element.end != $1.element.end { return $0.element.end < $1.element.end }
            return $0.offset < $1.offset
        }
        guard !sorted.isEmpty else { throw SubtitleError.noValidCues(format) }
        return sorted.enumerated().map { index, item in
            SubtitleCue(id: index, start: item.element.start, end: item.element.end, text: item.element.text)
        }
    }

    private static func parseTimedText(_ text: String, isVTT: Bool) -> [SubtitleCue] {
        let lines = text.components(separatedBy: "\n")
        var result: [SubtitleCue] = []
        var interval: (Double, Double)?
        var body: [String] = []
        var skippingBlock = false

        func finish() {
            if let (start, end) = interval {
                let content = cleanMarkup(body.joined(separator: "\n"), ass: false)
                if !content.isEmpty {
                    result.append(SubtitleCue(id: result.count, start: start, end: end, text: content))
                }
            }
            interval = nil
            body = []
        }

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                finish()
                skippingBlock = false
                continue
            }
            if skippingBlock { continue }
            if isVTT && interval == nil && (trimmed == "NOTE" || trimmed.hasPrefix("NOTE ") || trimmed.hasPrefix("NOTE\t") || trimmed == "STYLE" || trimmed == "REGION") {
                skippingBlock = true
                continue
            }
            if isVTT && interval == nil && (trimmed == "WEBVTT" || trimmed.hasPrefix("WEBVTT ") || trimmed.hasPrefix("WEBVTT\t")) { continue }
            if trimmed.contains("-->") {
                finish()
                interval = timingLine(trimmed)
                continue
            }
            // Identifiers can be arbitrary strings in WebVTT. Also tolerate adjacent cues without blank lines.
            if index + 1 < lines.count && lines[index + 1].contains("-->") && (isVTT || trimmed.allSatisfy(\.isNumber)) { continue }
            if interval != nil { body.append(line) }
        }
        finish()
        return result
    }

    private static func timingLine(_ line: String) -> (Double, Double)? {
        guard let arrow = line.range(of: "-->") else { return nil }
        let left = String(line[..<arrow.lowerBound]).trimmingCharacters(in: .whitespaces)
        let right = line[arrow.upperBound...].split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        guard let start = timestamp(left), let end = timestamp(right), end > start else { return nil }
        return (start, end)
    }

    private static func parseASS(_ text: String) -> [SubtitleCue] {
        var insideEvents = false
        var fields: [String] = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]
        var result: [SubtitleCue] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                insideEvents = trimmed.lowercased() == "[events]"
                continue
            }
            guard insideEvents, let colon = trimmed.firstIndex(of: ":") else { continue }
            let kind = trimmed[..<colon].lowercased()
            let value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if kind == "format" {
                fields = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                continue
            }
            guard kind == "dialogue", let startColumn = fields.firstIndex(of: "start"),
                  let endColumn = fields.firstIndex(of: "end"), let textColumn = fields.firstIndex(of: "text"),
                  textColumn == fields.count - 1 else { continue }
            // Text is the final ASS/SSA field and can contain any number of commas.
            let values = value.split(separator: ",", maxSplits: fields.count - 1, omittingEmptySubsequences: false)
            guard values.count == fields.count,
                  let start = timestamp(String(values[startColumn]).trimmingCharacters(in: .whitespaces)),
                  let end = timestamp(String(values[endColumn]).trimmingCharacters(in: .whitespaces)), end > start else { continue }
            let content = cleanMarkup(String(values[textColumn]), ass: true)
            if !content.isEmpty {
                result.append(SubtitleCue(id: result.count, start: start, end: end, text: content))
            }
        }
        return result
    }

    private static func timestamp(_ value: String) -> Double? {
        let parts = value.replacingOccurrences(of: ",", with: ".").split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        func digits(_ part: Substring) -> Bool {
            !part.isEmpty && part.unicodeScalars.allSatisfy { $0.value >= 48 && $0.value <= 57 }
        }
        let secondParts = parts.last!.split(separator: ".", omittingEmptySubsequences: false)
        guard (secondParts.count == 1 || secondParts.count == 2), secondParts.allSatisfy(digits),
              let seconds = Double(parts.last!), seconds < 60,
              parts.dropLast().allSatisfy(digits), let minutes = Double(parts[parts.count - 2]),
              parts.count != 3 || minutes < 60 else { return nil }
        let hours = parts.count == 3 ? (Double(parts[0]) ?? .infinity) : 0
        let result = hours * 3600 + minutes * 60 + seconds
        return result.isFinite ? result : nil
    }

    private static func cleanMarkup(_ text: String, ass: Bool) -> String {
        var result = text
        if ass {
            // ASS vector drawing commands are not text and are intentionally omitted.
            if result.range(of: #"\\p[1-9][0-9]*\b"#, options: .regularExpression) != nil { return "" }
            result = result.replacingOccurrences(of: #"\{\\[^}]*\}"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\N"#, with: "\n")
                .replacingOccurrences(of: #"\n"#, with: "\n")
                .replacingOccurrences(of: #"\h"#, with: "\u{00A0}")
        }
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</?[A-Za-z][^>]*>|<\d{2}:\d{2}(?::\d{2})?\.\d{3}>"#, with: "", options: .regularExpression)
        result = decodeEntities(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ text: String) -> String {
        let names = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}", "lrm": "\u{200E}", "rlm": "\u{200F}"]
        guard let expression = try? NSRegularExpression(pattern: #"&(#x[0-9a-fA-F]+|#X[0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]+);"#) else { return text }
        var result = text
        for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result), let nameRange = Range(match.range(at: 1), in: text) else { continue }
            let name = String(text[nameRange])
            var replacement = names[name]
            if name.hasPrefix("#") {
                let hexadecimal = name.lowercased().hasPrefix("#x")
                if let number = UInt32(name.dropFirst(hexadecimal ? 2 : 1), radix: hexadecimal ? 16 : 10),
                   let scalar = UnicodeScalar(number), number != 0 {
                    replacement = String(scalar)
                }
            }
            if let replacement { result.replaceSubrange(range, with: replacement) }
        }
        return result
    }

    private static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) { return String(data: data, encoding: .utf32LittleEndian) }
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) { return String(data: data, encoding: .utf32BigEndian) }
        if data.starts(with: [0xFF, 0xFE]) { return String(data: data, encoding: .utf16LittleEndian) }
        if data.starts(with: [0xFE, 0xFF]) { return String(data: data, encoding: .utf16BigEndian) }
        // A BOM-less UTF-16 SRT still has ASCII timestamps; their alternating NULs identify byte order.
        if data.contains(0), data.count.isMultiple(of: 2) {
            let bytes = Array(data.prefix(512))
            let evenNULs = bytes.enumerated().filter { $0.offset.isMultiple(of: 2) && $0.element == 0 }.count
            let oddNULs = bytes.enumerated().filter { !$0.offset.isMultiple(of: 2) && $0.element == 0 }.count
            if oddNULs > evenNULs + 2, let value = String(data: data, encoding: .utf16LittleEndian) { return value }
            if evenNULs > oddNULs + 2, let value = String(data: data, encoding: .utf16BigEndian) { return value }
        }
        if let value = String(data: data, encoding: .utf8) { return value }
        // Foundation's NSStringEncoding representation of GB18030 (CF encoding 0x0632).
        return String(data: data, encoding: String.Encoding(rawValue: 0x80000632))
    }
}
