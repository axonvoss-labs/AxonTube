import Foundation

/// Reading documents preserve each source cue once; they do not re-segment sentences.
public enum SubtitleDocumentExporter {
    public struct Output: Sendable {
        public let data: Data
        /// Primary paragraphs plus unmatched secondary paragraphs, not SRT time slices.
        public let cueCount: Int
    }

    public enum ExportError: BilingualError, Equatable, Sendable {
        case tooLarge
        public var message: LocalizedText {
            LocalizedText("The subtitle document exceeds the 64 MiB export limit. Load a smaller subtitle file and try again.", "字幕文档过大，无法导出；请载入较小的字幕文件后重试（文件上限 64 MiB）。")
        }
    }

    private static let maximumMilliseconds: Int64 = 35_999_999_999
    private static var maximumSeconds: Double { Double(maximumMilliseconds) / 1000 }
    private struct Cue {
        let start: Int64
        let end: Int64
        let text: String
    }
    private struct Entry {
        let primary: Cue?
        var secondary: [Cue]
        let anchor: Int64
        let order: Int
    }

    public static func txt(primary: SubtitleTrack, secondary: SubtitleTrack,
                           primaryOffset: Double = 0, secondaryOffset: Double = 0,
                           title: String = "双语字幕") throws -> Output {
        let entries = try arrange(primary, secondary, primaryOffset, secondaryOffset)
        var text = ""
        var bytes = 0
        try append(normalizedTitle(title) + "\n\n" + introduction(entries.count) + "\n\n",
                   to: &text, bytes: &bytes)
        for (index, entry) in entries.enumerated() {
            for (partIndex, part) in parts(entry, number: index + 1).enumerated() {
                if partIndex > 0 { try append("\n", to: &text, bytes: &bytes) }
                try append(part.label + "\n" + part.text + "\n", to: &text, bytes: &bytes)
            }
            try append("\n", to: &text, bytes: &bytes)
        }
        return Output(data: Data(text.utf8), cueCount: entries.count)
    }

    public static func docx(primary: SubtitleTrack, secondary: SubtitleTrack,
                            primaryOffset: Double = 0, secondaryOffset: Double = 0,
                            title: String = "双语字幕") throws -> Output {
        let entries = try arrange(primary, secondary, primaryOffset, secondaryOffset)
        var document = ""
        var bytes = 0
        try append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
                   to: &document, bytes: &bytes)
        try append(paragraph(normalizedTitle(title), style: "Title", keepNext: true), to: &document, bytes: &bytes)
        try append(paragraph(introduction(entries.count), style: "Metadata"),
                   to: &document, bytes: &bytes)
        for (index, entry) in entries.enumerated() {
            let content = parts(entry, number: index + 1)
            // Keep a short bilingual group together, but never chain a large block across pages.
            let short = content.count <= 4 && content.reduce(0, { $0 + $1.text.count }) <= 400
                && content.reduce(0, { $0 + $1.text.filter { $0 == "\n" }.count }) <= 8
            for (partIndex, part) in content.enumerated() {
                try append(paragraph(part.label, style: "Timestamp", keepNext: true, keepLines: true),
                           to: &document, bytes: &bytes)
                try append(paragraph(part.text, keepNext: short && partIndex < content.count - 1,
                                     keepLines: short, spaceAfter: partIndex == content.count - 1 ? 120 : 60),
                           to: &document, bytes: &bytes)
            }
        }
        try append("<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\" w:orient=\"portrait\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:header=\"720\" w:footer=\"720\" w:gutter=\"0\"/></w:sectPr></w:body></w:document>",
                   to: &document, bytes: &bytes)
        let files: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(packageRelationships.utf8)),
            ("word/document.xml", Data(document.utf8)),
            ("word/_rels/document.xml.rels", Data(documentRelationships.utf8)),
            ("word/styles.xml", Data(styles.utf8)),
            ("word/fontTable.xml", Data(fontTable.utf8)),
            ("word/settings.xml", Data(settings.utf8))
        ]
        return Output(data: try SubtitleDocumentZIP.encode(files), cueCount: entries.count)
    }

    private static func arrange(_ primary: SubtitleTrack, _ secondary: SubtitleTrack,
                                _ primaryOffset: Double, _ secondaryOffset: Double) throws -> [Entry] {
        guard primaryOffset.isFinite, secondaryOffset.isFinite,
              abs(primaryOffset) <= maximumSeconds, abs(secondaryOffset) <= maximumSeconds else {
            throw SubtitleExporter.ExportError.invalidOffset
        }
        let first = try prepare(primary, offset: primaryOffset)
        let second = try prepare(secondary, offset: secondaryOffset)
        guard !first.isEmpty || !second.isEmpty else { throw SubtitleExporter.ExportError.noContent }
        var entries = first.enumerated().map { Entry(primary: $0.element, secondary: [], anchor: $0.element.start, order: $0.offset) }
        var maximumEnd: Int64 = 0
        let prefixEnds = first.map { cue -> Int64 in maximumEnd = max(maximumEnd, cue.end); return maximumEnd }
        for (index, cue) in second.enumerated() {
            // Search only intervals that can overlap, including earlier long-running cues.
            var low = 0
            var high = first.count
            while low < high {
                let middle = low + (high - low) / 2
                if first[middle].start < cue.end { low = middle + 1 } else { high = middle }
            }
            var candidate = low - 1
            var best: Int?
            var bestOverlap: Int64 = 0
            var bestContainsMidpoint = false
            var bestDistance = Int64.max
            let midpointTwice = cue.start + cue.end
            while candidate >= 0, prefixEnds[candidate] > cue.start {
                let other = first[candidate]
                let overlap = min(cue.end, other.end) - max(cue.start, other.start)
                let contains = other.start * 2 <= midpointTwice && midpointTwice < other.end * 2
                let distance = abs(midpointTwice - (other.start + other.end))
                if overlap > 0 && (overlap > bestOverlap
                    || (overlap == bestOverlap && contains && !bestContainsMidpoint)
                    || (overlap == bestOverlap && contains == bestContainsMidpoint && distance < bestDistance)
                    || (overlap == bestOverlap && contains == bestContainsMidpoint && distance == bestDistance && candidate < (best ?? Int.max))) {
                    best = candidate; bestOverlap = overlap; bestContainsMidpoint = contains; bestDistance = distance
                }
                candidate -= 1
            }
            if let best { entries[best].secondary.append(cue) }
            else { entries.append(Entry(primary: nil, secondary: [cue], anchor: cue.start, order: first.count + index)) }
        }
        return entries.sorted { $0.anchor != $1.anchor ? $0.anchor < $1.anchor : $0.order < $1.order }
    }

    // Same validation/rounding contract as SRT, applied to raw cues before document matching.
    private static func prepare(_ track: SubtitleTrack, offset: Double) throws -> [Cue] {
        var result: [Cue] = []
        for cue in track.cues {
            guard cue.start.isFinite, cue.end.isFinite, cue.start >= 0, cue.end > cue.start else {
                throw SubtitleExporter.ExportError.invalidTime
            }
            guard cue.end <= maximumSeconds else { throw SubtitleExporter.ExportError.timeOutOfRange }
            let text = cue.text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            guard text.utf8.count <= SubtitleDocumentZIP.maximumBytes else { throw ExportError.tooLarge }
            let start = cue.start + offset
            let end = cue.end + offset
            guard start.isFinite, end.isFinite, start <= maximumSeconds, end <= maximumSeconds else {
                throw SubtitleExporter.ExportError.timeOutOfRange
            }
            guard end > 0 else { continue }
            let startMS = try milliseconds(max(0, start))
            let endMS = try milliseconds(end)
            guard endMS > startMS else { throw SubtitleExporter.ExportError.submillisecondCue }
            result.append(Cue(start: startMS, end: endMS, text: text))
        }
        return result
    }

    private static func milliseconds(_ seconds: Double) throws -> Int64 {
        let value = (seconds * 1000).rounded(.toNearestOrAwayFromZero)
        guard value.isFinite, value >= 0, value <= Double(maximumMilliseconds) else {
            throw SubtitleExporter.ExportError.timeOutOfRange
        }
        return Int64(value)
    }

    private static func parts(_ entry: Entry, number: Int) -> [(label: String, text: String)] {
        var result: [(label: String, text: String)] = []
        if let primary = entry.primary { result.append(("\(number)  原文  \(range(primary))", primary.text)) }
        for secondary in entry.secondary {
            let label = entry.primary == nil ? "\(number)  仅译文" : "译文"
            result.append(("\(label)  \(range(secondary))", secondary.text))
        }
        return result
    }

    private static func range(_ cue: Cue) -> String { "\(timestamp(cue.start)) – \(timestamp(cue.end))" }
    private static func timestamp(_ value: Int64) -> String {
        func pad(_ number: Int64, _ width: Int) -> String {
            let text = String(number)
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        return "\(pad(value / 3_600_000, 2)):\(pad(value / 60_000 % 60, 2)):\(pad(value / 1000 % 60, 2)).\(pad(value % 1000, 3))"
    }
    private static func normalizedTitle(_ title: String) -> String {
        let value = title.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "双语字幕" : value
    }
    private static func introduction(_ count: Int) -> String {
        return "共 \(count) 段。原文在上，译文在下；时间标记已保留当前字幕的时间调整。"
    }
    private static func append(_ piece: String, to value: inout String, bytes: inout Int) throws {
        let extra = piece.utf8.count
        guard bytes <= SubtitleDocumentZIP.maximumBytes, extra <= SubtitleDocumentZIP.maximumBytes - bytes else { throw ExportError.tooLarge }
        value += piece; bytes += extra
    }

    private static func paragraph(_ text: String, style: String = "Normal", keepNext: Bool = false,
                                  keepLines: Bool = false, spaceAfter: Int? = nil) -> String {
        let isTitle = style == "Title"
        let secondary = style == "Metadata" || style == "Timestamp"
        let size = isTitle ? 40 : (secondary ? 20 : 22)
        let after = spaceAfter ?? (isTitle ? 180 : (style == "Metadata" ? 200 : (style == "Timestamp" ? 40 : 80)))
        let spacing = "<w:spacing w:before=\"0\" w:after=\"\(after)\" w:line=\"276\" w:lineRule=\"auto\"/>"
        // Repeat the style's essential typography for readers that ignore styles.xml (AppKit).
        let runProperties = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:eastAsia=\"PingFang SC\" w:cs=\"Arial\"/>\(isTitle ? "<w:b/>" : "")<w:color w:val=\"\(secondary ? "555555" : "000000")\"/><w:sz w:val=\"\(size)\"/><w:szCs w:val=\"\(size)\"/><w:lang w:val=\"en-US\" w:eastAsia=\"zh-CN\"/></w:rPr>"
        return "<w:p><w:pPr><w:pStyle w:val=\"\(style)\"/><w:keepNext w:val=\"\(keepNext ? 1 : 0)\"/><w:keepLines w:val=\"\(keepLines ? 1 : 0)\"/>\(spacing)</w:pPr><w:r>\(runProperties)\(runText(text))</w:r></w:p>"
    }

    private static func runText(_ text: String) -> String {
        var result = "<w:t xml:space=\"preserve\">"
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 9: result += "</w:t><w:tab/><w:t xml:space=\"preserve\">"
            case 10, 13: result += "</w:t><w:br/><w:t xml:space=\"preserve\">"
            case 38: result += "&amp;"
            case 60: result += "&lt;"
            case 62: result += "&gt;"
            case 34: result += "&quot;"
            case 39: result += "&apos;"
            case 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: result.unicodeScalars.append(scalar)
            default: result += "\u{FFFD}" // Preserve a visible replacement for illegal XML 1.0 characters.
            }
        }
        return result + "</w:t>"
    }

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/><Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/></Types>
    """
    private static let packageRelationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
    """
    private static let documentRelationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/></Relationships>
    """
    private static let styles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="PingFang SC" w:cs="Arial"/><w:color w:val="000000"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US" w:eastAsia="zh-CN"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:widowControl/><w:spacing w:after="80" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
    <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
    <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="0" w:after="180"/></w:pPr><w:rPr><w:b/><w:color w:val="000000"/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr></w:style>
    <w:style w:type="paragraph" w:styleId="Metadata"><w:name w:val="Metadata"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="200"/></w:pPr><w:rPr><w:color w:val="555555"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr></w:style>
    <w:style w:type="paragraph" w:styleId="Timestamp"><w:name w:val="Timestamp"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="0" w:after="40"/></w:pPr><w:rPr><w:color w:val="555555"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr></w:style>
    </w:styles>
    """
    private static let fontTable = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:font w:name="Arial"><w:altName w:val="Liberation Sans"/><w:family w:val="swiss"/></w:font><w:font w:name="PingFang SC"><w:altName w:val="Microsoft YaHei"/><w:family w:val="swiss"/></w:font></w:fonts>
    """
    private static let settings = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:defaultTabStop w:val="720"/><w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat></w:settings>
    """
}

/// Small deterministic ZIP writer: stored entries only, no external process or ZIP64 truncation.
enum SubtitleDocumentZIP {
    static let maximumBytes = 64 * 1_024 * 1_024

    static func encode(_ files: [(name: String, data: Data)], limit: Int = maximumBytes) throws -> Data {
        guard limit >= 0, limit <= maximumBytes, let count = UInt16(exactly: files.count) else {
            throw SubtitleDocumentExporter.ExportError.tooLarge
        }
        var archive = Data()
        var directory = Data()
        for file in files {
            let name = Data(file.name.utf8)
            guard let nameSize = UInt16(exactly: name.count), let size = UInt32(exactly: file.data.count),
                  let offset = UInt32(exactly: archive.count),
                  file.data.count <= limit, name.count <= limit,
                  archive.count + directory.count + 30 + 46 + 2 * name.count + file.data.count + 22 <= limit else {
                throw SubtitleDocumentExporter.ExportError.tooLarge
            }
            let checksum = crc32(file.data)
            archive.documentUInt32(0x04034b50); archive.documentUInt16(20); archive.documentUInt16(0x0800)
            archive.documentUInt16(0); archive.documentUInt16(0); archive.documentUInt16(33)
            archive.documentUInt32(checksum); archive.documentUInt32(size); archive.documentUInt32(size)
            archive.documentUInt16(nameSize); archive.documentUInt16(0); archive.append(name); archive.append(file.data)
            directory.documentUInt32(0x02014b50); directory.documentUInt16(20); directory.documentUInt16(20)
            directory.documentUInt16(0x0800); directory.documentUInt16(0); directory.documentUInt16(0); directory.documentUInt16(33)
            directory.documentUInt32(checksum); directory.documentUInt32(size); directory.documentUInt32(size)
            directory.documentUInt16(nameSize); directory.documentUInt16(0); directory.documentUInt16(0)
            directory.documentUInt16(0); directory.documentUInt16(0); directory.documentUInt32(0); directory.documentUInt32(offset)
            directory.append(name)
        }
        guard archive.count + directory.count + 22 <= limit,
              let directorySize = UInt32(exactly: directory.count), let directoryOffset = UInt32(exactly: archive.count) else {
            throw SubtitleDocumentExporter.ExportError.tooLarge
        }
        archive.append(directory)
        archive.documentUInt32(0x06054b50); archive.documentUInt16(0); archive.documentUInt16(0)
        archive.documentUInt16(count); archive.documentUInt16(count)
        archive.documentUInt32(directorySize); archive.documentUInt32(directoryOffset); archive.documentUInt16(0)
        return archive
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? (value >> 1) ^ 0xEDB88320 : value >> 1 }
        return value
    }
    private static func crc32(_ data: Data) -> UInt32 {
        var value = UInt32.max
        for byte in data { value = (value >> 8) ^ crcTable[Int((value ^ UInt32(byte)) & 0xFF)] }
        return value ^ UInt32.max
    }
}

private extension Data {
    mutating func documentUInt16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value)); append(UInt8(truncatingIfNeeded: value >> 8))
    }
    mutating func documentUInt32(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) { append(UInt8(truncatingIfNeeded: value >> shift)) }
    }
}
