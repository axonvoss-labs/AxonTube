import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest
@testable import PlayerCore

final class SubtitleDocumentExporterTests: XCTestCase {
    private let empty = SubtitleTrack(cues: [])
    private func cue(_ start: Double, _ end: Double, _ text: String, id: Int = 0) -> SubtitleCue {
        SubtitleCue(id: id, start: start, end: end, text: text)
    }
    private func text(_ output: SubtitleDocumentExporter.Output) throws -> String {
        try XCTUnwrap(String(data: output.data, encoding: .utf8))
    }
    private func export(_ docx: Bool, _ primary: SubtitleTrack, _ secondary: SubtitleTrack,
                        _ primaryOffset: Double = 0, _ secondaryOffset: Double = 0) throws -> SubtitleDocumentExporter.Output {
        if docx { return try SubtitleDocumentExporter.docx(primary: primary, secondary: secondary, primaryOffset: primaryOffset, secondaryOffset: secondaryOffset) }
        return try SubtitleDocumentExporter.txt(primary: primary, secondary: secondary, primaryOffset: primaryOffset, secondaryOffset: secondaryOffset)
    }
    private func occurrences(_ token: String, in text: String) -> Int { text.components(separatedBy: token).count - 1 }

    func testReadingDocumentAssignsTranslationOnceAndKeepsUnmatchedChronologically() throws {
        let primary = SubtitleTrack(cues: [cue(0, 2, "EN_FIRST"), cue(2, 4, "EN_SECOND"), cue(8, 9, "EN_LAST")])
        let secondary = SubtitleTrack(cues: [cue(1, 3, "中间译文"), cue(5, 6, "独立译文")])
        let output = try SubtitleDocumentExporter.txt(primary: primary, secondary: secondary)
        let value = try text(output)
        XCTAssertEqual(output.cueCount, 4)
        for token in ["EN_FIRST", "EN_SECOND", "EN_LAST", "中间译文", "独立译文"] { XCTAssertEqual(occurrences(token, in: value), 1) }
        let second = try XCTUnwrap(value.range(of: "EN_SECOND"))
        let translated = try XCTUnwrap(value.range(of: "中间译文"))
        let orphan = try XCTUnwrap(value.range(of: "独立译文"))
        let last = try XCTUnwrap(value.range(of: "EN_LAST"))
        XCTAssertTrue(second.lowerBound < translated.lowerBound && translated.lowerBound < orphan.lowerBound && orphan.lowerBound < last.lowerBound)
        XCTAssertTrue(value.contains("3  仅译文  00:00:05.000 – 00:00:06.000"))
        XCTAssertTrue(value.contains("译文  00:00:01.000 – 00:00:03.000"))
    }

    func testAlreadySelectedRawCuesAreNotJoinedOrRepeatedLikeSRTSlices() throws {
        let primary = SubtitleTrack(cues: [cue(0, 1, "I like"), cue(1, 2, "to read.")])
        let secondary = SubtitleTrack(cues: [cue(0, 2, "我喜欢阅读。")])
        let output = try SubtitleDocumentExporter.txt(primary: primary, secondary: secondary)
        let value = try text(output)
        XCTAssertEqual(output.cueCount, 2)
        XCTAssertEqual(occurrences("我喜欢阅读。", in: value), 1)
        XCTAssertTrue(!value.contains("I like to read."))
        XCTAssertTrue(value.contains("1  原文  00:00:00.000 – 00:00:01.000\nI like"))
        XCTAssertTrue(value.contains("2  原文  00:00:01.000 – 00:00:02.000\nto read."))
    }

    func testLongestPositiveOverlapWinsAndEarlierLongOverlapIsNotLost() throws {
        let primary = SubtitleTrack(cues: [cue(0, 20, "LONG_SOURCE", id: 8), cue(2, 3, "SHORT_SOURCE", id: 8)])
        let secondary = SubtitleTrack(cues: [cue(4, 5, "较晚译文"), cue(8, 9, "另一译文")])
        let value = try text(SubtitleDocumentExporter.txt(primary: primary, secondary: secondary))
        let long = try XCTUnwrap(value.range(of: "LONG_SOURCE"))
        let first = try XCTUnwrap(value.range(of: "较晚译文"))
        let second = try XCTUnwrap(value.range(of: "另一译文"))
        let short = try XCTUnwrap(value.range(of: "SHORT_SOURCE"))
        XCTAssertTrue(long.lowerBound < first.lowerBound && first.lowerBound < second.lowerBound && second.lowerBound < short.lowerBound)
        XCTAssertEqual(occurrences("较晚译文", in: value), 1)
        XCTAssertEqual(occurrences("另一译文", in: value), 1)
    }

    func testOverlapTieUsesMidpointThenNearestCenterAndStableSourceOrder() throws {
        let primary = SubtitleTrack(cues: [cue(0, 4, "WIDE"), cue(1, 2, "NEAR_FIRST", id: 7), cue(1, 2, "NEAR_SECOND", id: 7)])
        let value = try text(SubtitleDocumentExporter.txt(primary: primary, secondary: SubtitleTrack(cues: [cue(1, 2, "唯一译文")])))
        let winner = try XCTUnwrap(value.range(of: "NEAR_FIRST"))
        let translation = try XCTUnwrap(value.range(of: "唯一译文"))
        let later = try XCTUnwrap(value.range(of: "NEAR_SECOND"))
        XCTAssertTrue(winner.lowerBound < translation.lowerBound && translation.lowerBound < later.lowerBound)
        XCTAssertEqual(occurrences("唯一译文", in: value), 1)
    }

    func testChineseOnlyAndTouchingIntervalsRemainSeparate() throws {
        let chinese = SubtitleTrack(cues: [cue(1, 2, "第一条"), cue(4, 5, "第二条")])
        let only = try SubtitleDocumentExporter.txt(primary: empty, secondary: chinese)
        XCTAssertEqual(only.cueCount, 2)
        let value = try text(only)
        XCTAssertTrue(value.contains("1  仅译文"))
        let touching = try SubtitleDocumentExporter.txt(primary: SubtitleTrack(cues: [cue(0, 1, "English")]), secondary: chinese)
        XCTAssertEqual(touching.cueCount, 3)
    }

    func testOffsetsClipOnceAndEachTrackKeepsItsOwnTimeRange() throws {
        let primary = SubtitleTrack(cues: [cue(0, 1, "DROP_ME"), cue(1, 3, "KEEP_ME")])
        let secondary = SubtitleTrack(cues: [cue(0, 1, "你好")])
        let before = primary.cues
        let beforeChinese = secondary.cues
        let output = try SubtitleDocumentExporter.txt(primary: primary, secondary: secondary, primaryOffset: -2, secondaryOffset: 0.5)
        let value = try text(output)
        XCTAssertEqual(output.cueCount, 1)
        XCTAssertTrue(!value.contains("DROP_ME"))
        XCTAssertTrue(value.contains("原文  00:00:00.000 – 00:00:01.000"))
        XCTAssertTrue(value.contains("译文  00:00:00.500 – 00:00:01.500"))
        XCTAssertTrue(value.contains("时间标记已保留当前字幕的时间调整"))
        XCTAssertEqual(primary.cues, before)
        XCTAssertEqual(secondary.cues, beforeChinese)
    }

    func testRoundingAcrossHoursAndMoreThanTwoHourDigits() throws {
        let primary = SubtitleTrack(cues: [cue(3599.9995, 3601.2345, "HOUR"), cue(359999.9996, 360000.0014, "LONG_TIME")])
        let value = try text(SubtitleDocumentExporter.txt(primary: primary, secondary: empty))
        XCTAssertTrue(value.contains("01:00:00.000 – 01:00:01.235"))
        XCTAssertTrue(value.contains("100:00:00.000 – 100:00:00.001"))
    }

    func testPlainTextKeepsUnicodeTabsBlankLinesAndLiteralMarkupWithoutGeneratedEntities() throws {
        let content = "中文 café 😀 <tag> & >\tTab\n\n下行 &lt;literal&gt;"
        let output = try SubtitleDocumentExporter.txt(primary: SubtitleTrack(cues: [cue(0, 1, content)]), secondary: empty, title: "阅读标题")
        let value = try text(output)
        XCTAssertTrue(value.hasPrefix("阅读标题\n\n"))
        XCTAssertTrue(value.contains(content))
        XCTAssertTrue(!value.contains("&amp;") && !value.contains("&lt;tag&gt;"))
        XCTAssertEqual(output.data, Data(value.utf8))
    }

    func testBothFormatsUseSRTErrorSemanticsForEmptyOffsetsAndTimeLimits() {
        let valid = SubtitleTrack(cues: [cue(0, 1, "Valid")])
        for docx in [false, true] {
            XCTAssertThrowsError(try export(docx, empty, empty)) { XCTAssertEqual($0 as? SubtitleExporter.ExportError, .noContent) }
            XCTAssertThrowsError(try export(docx, valid, empty, -2)) { XCTAssertEqual($0 as? SubtitleExporter.ExportError, .noContent) }
            XCTAssertThrowsError(try export(docx, valid, empty, .nan)) { XCTAssertEqual($0 as? SubtitleExporter.ExportError, .invalidOffset) }
            XCTAssertThrowsError(try export(docx, valid, empty, 0, .infinity)) { XCTAssertEqual($0 as? SubtitleExporter.ExportError, .invalidOffset) }
            XCTAssertThrowsError(try export(docx, SubtitleTrack(cues: [cue(1e100, 1e101, "Huge")]), empty)) {
                XCTAssertEqual($0 as? SubtitleExporter.ExportError, .timeOutOfRange)
            }
            XCTAssertThrowsError(try export(docx, SubtitleTrack(cues: [cue(1, 1.0001, "Brief")]), empty)) {
                XCTAssertEqual($0 as? SubtitleExporter.ExportError, .submillisecondCue)
            }
        }
    }

    func testDOCXZIPAndXMLAreValidAndContainOnlyInternalOOXMLParts() throws {
        let track = SubtitleTrack(cues: [cue(1, 2, "Hello 中文")])
        let output = try SubtitleDocumentExporter.docx(primary: track, secondary: empty)
        let files = try SubtitleDocumentZIPInspector.read(output.data)
        XCTAssertEqual(Set(files.keys), Set(["[Content_Types].xml", "_rels/.rels", "word/document.xml", "word/_rels/document.xml.rels", "word/styles.xml", "word/fontTable.xml", "word/settings.xml"]))
        for data in files.values {
            let parser = XMLParser(data: data)
            parser.shouldResolveExternalEntities = false
            XCTAssertTrue(parser.parse(), "Every package part must be well-formed XML")
            let xml = String(decoding: data, as: UTF8.self)
            XCTAssertTrue(!xml.contains("TargetMode=\"External\"") && !xml.contains("vbaProject") && !xml.contains("attachedTemplate"))
        }
        let document = try XCTUnwrap(files["word/document.xml"])
        let paragraphs = try SubtitleDocumentXMLInspector.read(document)
        XCTAssertTrue(paragraphs.contains(where: { $0.text == "Hello 中文" }))
        let again = try SubtitleDocumentExporter.docx(primary: track, secondary: empty)
        XCTAssertEqual(output.data, again.data, "No clocks, personal metadata, or random identifiers in exports")
    }

    func testDOCXEscapingControlsTabsAndLineBreaksPreserveReadableText() throws {
        let content = "Literal <tag> & \"quote\" 'apostrophe' &amp;\tTab\n\n中文 😀\u{0001}\u{FFFE}"
        let title = "Title <&>"
        let output = try SubtitleDocumentExporter.docx(primary: SubtitleTrack(cues: [cue(0, 1, content)]), secondary: empty, title: title)
        let files = try SubtitleDocumentZIPInspector.read(output.data)
        let paragraphs = try SubtitleDocumentXMLInspector.read(XCTUnwrap(files["word/document.xml"]))
        XCTAssertEqual(paragraphs.first?.text, title)
        XCTAssertEqual(paragraphs.last?.text, content.replacingOccurrences(of: "\u{0001}", with: "�").replacingOccurrences(of: "\u{FFFE}", with: "�"))
        XCTAssertEqual(paragraphs.first?.style, "Title")
    }

    func testDOCXLetterMarginsBlackTitleAndReadableLatinCJKFonts() throws {
        let output = try SubtitleDocumentExporter.docx(primary: SubtitleTrack(cues: [cue(0, 2, "English")]), secondary: SubtitleTrack(cues: [cue(0, 2, "中文")]))
        let files = try SubtitleDocumentZIPInspector.read(output.data)
        let document = String(decoding: try XCTUnwrap(files["word/document.xml"]), as: UTF8.self)
        let styles = String(decoding: try XCTUnwrap(files["word/styles.xml"]), as: UTF8.self)
        XCTAssertTrue(document.contains("w:w=\"12240\" w:h=\"15840\" w:orient=\"portrait\""))
        XCTAssertTrue(document.contains("w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\""))
        XCTAssertTrue(styles.contains("w:styleId=\"Title\"") && styles.contains("w:color w:val=\"000000\""))
        XCTAssertTrue(styles.contains("w:ascii=\"Arial\"") && styles.contains("w:eastAsia=\"PingFang SC\"") && styles.contains("w:sz w:val=\"22\""))
        XCTAssertTrue(document.contains("w:ascii=\"Arial\"") && document.contains("w:eastAsia=\"PingFang SC\""))
        XCTAssertTrue(document.contains("<w:b/><w:color w:val=\"000000\"/><w:sz w:val=\"40\"/>"))
        XCTAssertTrue(document.contains("<w:sz w:val=\"22\"/>") && document.contains("w:line=\"276\""))
        XCTAssertTrue(!styles.contains("w:pBdr") && !styles.contains("<w:u "))
    }

    func testDOCXKeepsShortPairsTogetherButAllowsLongBodyToPaginate() throws {
        let short = try SubtitleDocumentExporter.docx(primary: SubtitleTrack(cues: [cue(0, 2, "Short English")]), secondary: SubtitleTrack(cues: [cue(0, 2, "短译文")]))
        let shortFiles = try SubtitleDocumentZIPInspector.read(short.data)
        let shortParagraphs = try SubtitleDocumentXMLInspector.read(XCTUnwrap(shortFiles["word/document.xml"]))
        let english = try XCTUnwrap(shortParagraphs.first(where: { $0.text == "Short English" }))
        let chinese = try XCTUnwrap(shortParagraphs.first(where: { $0.text == "短译文" }))
        XCTAssertEqual(english.keepNext, true); XCTAssertEqual(english.keepLines, true)
        XCTAssertEqual(chinese.keepNext, false); XCTAssertEqual(chinese.keepLines, true)
        let longText = String(repeating: "Long readable text with natural wrapping. ", count: 150).trimmingCharacters(in: .whitespaces)
        let long = try SubtitleDocumentExporter.docx(primary: SubtitleTrack(cues: [cue(0, 2, longText)]), secondary: SubtitleTrack(cues: [cue(0, 2, "长段译文")]))
        let longFiles = try SubtitleDocumentZIPInspector.read(long.data)
        let longParagraphs = try SubtitleDocumentXMLInspector.read(XCTUnwrap(longFiles["word/document.xml"]))
        let body = try XCTUnwrap(longParagraphs.first(where: { $0.text == longText }))
        XCTAssertEqual(body.keepNext, false); XCTAssertEqual(body.keepLines, false)
    }

    func testZIPRejectsCapacityAndFieldOverflowBeforeWriting() {
        let file = (name: "test.xml", data: Data("123456789".utf8))
        XCTAssertThrowsError(try SubtitleDocumentZIP.encode([file], limit: 20)) { XCTAssertEqual($0 as? SubtitleDocumentExporter.ExportError, .tooLarge) }
        XCTAssertThrowsError(try SubtitleDocumentZIP.encode([file], limit: Int.max))
        XCTAssertThrowsError(try SubtitleDocumentZIP.encode([(String(repeating: "a", count: 65536), Data())]))
        XCTAssertThrowsError(try SubtitleDocumentZIP.encode(Array(repeating: file, count: 65536)))
    }

    func testZIPCRCMatchesPublishedCheckVector() throws {
        let bytes = try SubtitleDocumentZIP.encode([(name: "check.txt", data: Data("123456789".utf8))])
        let files = try SubtitleDocumentZIPInspector.read(bytes)
        XCTAssertEqual(files["check.txt"], Data("123456789".utf8))
        let checksum = UInt32(bytes[14]) | UInt32(bytes[15]) << 8 | UInt32(bytes[16]) << 16 | UInt32(bytes[17]) << 24
        XCTAssertEqual(checksum, 0xCBF43926)
    }
}

private enum SubtitleDocumentZIPInspector {
    enum Invalid: Error { case archive }
    static func read(_ data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        func require(_ condition: Bool) throws { if !condition { throw Invalid.archive } }
        func integer(_ offset: Int, _ count: Int) throws -> UInt32 {
            try require(offset >= 0 && offset <= bytes.count && count <= bytes.count - offset)
            return (0..<count).reduce(UInt32(0)) { $0 | UInt32(bytes[offset + $1]) << (8 * $1) }
        }
        try require(bytes.count >= 22)
        let footer = bytes.count - 22
        try require(integer(footer, 4) == 0x06054b50)
        let count = Int(try integer(footer + 10, 2))
        let directorySize = Int(try integer(footer + 12, 4))
        let directoryOffset = Int(try integer(footer + 16, 4))
        try require(directoryOffset + directorySize == footer)
        var position = directoryOffset
        var result: [String: Data] = [:]
        for _ in 0..<count {
            try require(integer(position, 4) == 0x02014b50)
            try require(integer(position + 10, 2) == 0)
            let checksum = try integer(position + 16, 4)
            let size = Int(try integer(position + 24, 4))
            let nameLength = Int(try integer(position + 28, 2))
            let extraLength = Int(try integer(position + 30, 2))
            let commentLength = Int(try integer(position + 32, 2))
            let local = Int(try integer(position + 42, 4))
            try require(position + 46 + nameLength <= footer)
            let nameBytes = Array(bytes[(position + 46)..<(position + 46 + nameLength)])
            guard let name = String(bytes: nameBytes, encoding: .utf8), result[name] == nil else { throw Invalid.archive }
            try require(integer(local, 4) == 0x04034b50)
            try require(integer(local + 8, 2) == 0 && integer(local + 14, 4) == checksum)
            try require(integer(local + 18, 4) == UInt32(size) && integer(local + 22, 4) == UInt32(size))
            try require(integer(local + 26, 2) == UInt32(nameLength))
            let localExtra = Int(try integer(local + 28, 2))
            let start = local + 30 + nameLength + localExtra
            try require(start + size <= directoryOffset)
            try require(Array(bytes[(local + 30)..<(local + 30 + nameLength)]) == nameBytes)
            let content = Data(bytes[start..<(start + size)])
            var crc = UInt32.max
            for byte in content {
                crc ^= UInt32(byte)
                for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 }
            }
            try require(crc ^ UInt32.max == checksum)
            result[name] = content
            position += 46 + nameLength + extraLength + commentLength
        }
        try require(position == footer)
        return result
    }
}

private final class SubtitleDocumentXMLInspector: NSObject, XMLParserDelegate {
    struct Paragraph {
        var text = ""
        var style = ""
        var keepNext = false
        var keepLines = false
    }
    private var current: Paragraph?
    private var insideText = false
    private var paragraphs: [Paragraph] = []
    static func read(_ data: Data) throws -> [Paragraph] {
        let delegate = SubtitleDocumentXMLInspector()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? SubtitleDocumentZIPInspector.Invalid.archive }
        return delegate.paragraphs
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        switch elementName {
        case "w:p": current = Paragraph()
        case "w:pStyle": current?.style = attributes["w:val"] ?? ""
        case "w:keepNext": current?.keepNext = attributes["w:val"] != "0"
        case "w:keepLines": current?.keepLines = attributes["w:val"] != "0"
        case "w:t": insideText = true
        case "w:tab": current?.text += "\t"
        case "w:br": current?.text += "\n"
        default: break
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if insideText { current?.text += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:t" { insideText = false }
        if elementName == "w:p", let paragraph = current { paragraphs.append(paragraph); current = nil }
    }
}
