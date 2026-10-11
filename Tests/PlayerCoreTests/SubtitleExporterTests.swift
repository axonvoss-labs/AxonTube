import Foundation
import XCTest
@testable import PlayerCore

final class SubtitleExporterTests: XCTestCase {
    private let empty = SubtitleTrack(cues: [])

    private func cue(_ start: Double, _ end: Double, _ text: String, id: Int = 0) -> SubtitleCue {
        SubtitleCue(id: id, start: start, end: end, text: text)
    }

    private func parse(_ output: SubtitleExporter.Output) throws -> [SubtitleCue] {
        let cues = try SubtitleParser.parse(output.text, fileExtension: "srt")
        XCTAssertEqual(cues.count, output.cueCount)
        return cues
    }

    func testAlignedBilingualSRTAndRoundTrip() throws {
        let result = try SubtitleExporter.srt(primary: SubtitleTrack(cues: [cue(1, 3, "Hello.")]),
                                             secondary: SubtitleTrack(cues: [cue(1, 3, "你好。")]))
        XCTAssertEqual(result.text, "1\n00:00:01,000 --> 00:00:03,000\nHello.\n你好。\n")
        XCTAssertEqual(try parse(result), [cue(1, 3, "Hello.\n你好。")])
    }

    func testStaggeredTimelinesPreserveMissingAndUnmatchedParts() throws {
        let primary = SubtitleTrack(cues: [cue(0, 2, "One"), cue(4, 6, "Two")])
        let secondary = SubtitleTrack(cues: [cue(1, 3, "一"), cue(3.5, 4.5, "独立译文"), cue(7, 8, "尾声")])
        let cues = try parse(SubtitleExporter.srt(primary: primary, secondary: secondary))
        XCTAssertEqual(cues.map(\.start), [0, 1, 2, 3.5, 4, 4.5, 7])
        XCTAssertEqual(cues.map(\.end), [1, 2, 3, 4, 4.5, 6, 8])
        XCTAssertEqual(cues.map(\.text), ["One", "One\n一", "一", "独立译文", "Two\n独立译文", "Two", "尾声"])
    }

    func testIndependentOffsetsAppliedOnceAndClippedAtZero() throws {
        let primary = SubtitleTrack(cues: [cue(0, 1, "Entirely before zero"), cue(1, 3, "Hello")])
        let secondary = SubtitleTrack(cues: [cue(0, 1, "你好")])
        let cues = try parse(SubtitleExporter.srt(primary: primary, secondary: secondary,
                                                 primaryOffset: -2, secondaryOffset: 0.5))
        XCTAssertEqual(cues.map(\.start), [0, 0.5, 1])
        XCTAssertEqual(cues.map(\.end), [0.5, 1, 1.5])
        XCTAssertEqual(cues.map(\.text), ["Hello", "Hello\n你好", "你好"])
    }

    func testSameTrackOverlapsAndRepeatedIDsKeepAllActiveText() throws {
        let primary = SubtitleTrack(cues: [cue(0, 4, "Long", id: 7), cue(1, 2, "Short", id: 7)])
        let secondary = SubtitleTrack(cues: [cue(1.5, 3, "译一"), cue(2.5, 3.5, "译二")])
        let cues = try parse(SubtitleExporter.srt(primary: primary, secondary: secondary))
        XCTAssertEqual(cues.map(\.start), [0, 1, 1.5, 2, 2.5, 3, 3.5])
        XCTAssertEqual(cues.map(\.end), [1, 1.5, 2, 2.5, 3, 3.5, 4])
        XCTAssertEqual(cues.map(\.text), ["Long", "Long\nShort", "Long\nShort\n译一", "Long\n译一", "Long\n译一\n译二", "Long\n译二", "Long"])
    }

    func testAdjacentIdenticalContentMergesButGapDoesNot() throws {
        let primary = SubtitleTrack(cues: [cue(0, 1, "Same"), cue(1, 2, "Same"), cue(3, 4, "Same")])
        let cues = try parse(SubtitleExporter.srt(primary: primary, secondary: empty))
        XCTAssertEqual(cues.map(\.start), [0, 3])
        XCTAssertEqual(cues.map(\.end), [2, 4])
        XCTAssertEqual(cues.map(\.text), ["Same", "Same"])
    }

    func testTouchingDifferentTracksDoNotCreateFalseOverlap() throws {
        let result = try SubtitleExporter.srt(primary: SubtitleTrack(cues: [cue(0, 1, "English")]),
                                             secondary: SubtitleTrack(cues: [cue(1, 2, "中文")]))
        XCTAssertEqual(try parse(result).map(\.text), ["English", "中文"])
    }

    func testMillisecondRoundingCarriesAcrossMinuteAndHour() throws {
        let primary = SubtitleTrack(cues: [cue(59.9995, 61.2345, "Minute"), cue(3599.9995, 3661.2345, "Hour")])
        let result = try SubtitleExporter.srt(primary: primary, secondary: empty)
        let cues = try parse(result)
        XCTAssertEqual(cues.map(\.start), [60, 3600])
        XCTAssertEqual(cues.map(\.end), [61.235, 3661.235])
        XCTAssertTrue(result.text.contains("00:01:00,000 --> 00:01:01,235"))
        XCTAssertTrue(result.text.contains("01:00:00,000 --> 01:01:01,235"))
    }

    func testMoreThanTwoHourDigitsAndMaximumSupportedTime() throws {
        let primary = SubtitleTrack(cues: [cue(359999.9996, 360000.0014, "100 hours"),
                                          cue(35_999_998, 35_999_999.999, "Upper boundary")])
        let result = try SubtitleExporter.srt(primary: primary, secondary: empty)
        let cues = try parse(result)
        XCTAssertEqual(cues.map(\.start), [360000, 35_999_998])
        XCTAssertEqual(cues.map(\.end), [360000.001, 35_999_999.999])
        XCTAssertTrue(result.text.contains("100:00:00,000 --> 100:00:00,001"))
        XCTAssertTrue(result.text.contains("9999:59:59,999"))
    }

    func testUnicodeLiteralMarkupArrowsEntitiesAndBlankLinesRoundTrip() throws {
        let english = "<b>原文</b> & café 😀 --> 保留\n\n下行\n  \n末行 &lt;字&gt;"
        let chinese = "译文「你好」\n第二行"
        let result = try SubtitleExporter.srt(primary: SubtitleTrack(cues: [cue(0, 2, "  " + english + "\r\n")]),
                                             secondary: SubtitleTrack(cues: [cue(0, 2, chinese)]))
        XCTAssertEqual(try parse(result).map(\.text), [english + "\n" + chinese])
        XCTAssertTrue(result.text.contains("&lt;b&gt;原文&lt;/b&gt;"))
        XCTAssertTrue(result.text.contains("--&gt;"))
        XCTAssertEqual(result.text.components(separatedBy: "\n\n").count, 1)
    }

    func testIdenticalOverlappingCuesAreNotSilentlyDeduplicated() throws {
        let primary = SubtitleTrack(cues: [cue(0, 2, "Echo"), cue(1, 3, "Echo")])
        XCTAssertEqual(try parse(SubtitleExporter.srt(primary: primary, secondary: empty)).map(\.text),
                       ["Echo", "Echo\nEcho", "Echo"])
    }

    func testEmptyBlankAndEntirelyClippedTracksReportNoContent() {
        for primary in [empty, SubtitleTrack(cues: [cue(0, 1, " \n\t\r\n")]), SubtitleTrack(cues: [cue(0, 1, "Before")])] {
            XCTAssertThrowsError(try SubtitleExporter.srt(primary: primary, secondary: empty, primaryOffset: -2)) {
                XCTAssertEqual($0 as? SubtitleExporter.ExportError, .noContent)
            }
        }
    }

    func testInvalidAndExcessiveOffsetsAreRejected() {
        let primary = SubtitleTrack(cues: [cue(0, 1, "Text")])
        for offset in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
            XCTAssertThrowsError(try SubtitleExporter.srt(primary: primary, secondary: empty, primaryOffset: offset)) {
                XCTAssertEqual($0 as? SubtitleExporter.ExportError, .invalidOffset)
            }
            XCTAssertThrowsError(try SubtitleExporter.srt(primary: primary, secondary: empty, secondaryOffset: offset))
        }
    }

    func testExcessiveOriginalAndShiftedTimesAreRejectedBeforeIntegerConversion() {
        XCTAssertThrowsError(try SubtitleExporter.srt(primary: SubtitleTrack(cues: [cue(1e100, 1e101, "Huge")]), secondary: empty)) {
            XCTAssertEqual($0 as? SubtitleExporter.ExportError, .timeOutOfRange)
        }
        XCTAssertThrowsError(try SubtitleExporter.srt(primary: SubtitleTrack(cues: [cue(35_999_998, 35_999_999, "Shifted")]),
                                                     secondary: empty, primaryOffset: 2)) {
            XCTAssertEqual($0 as? SubtitleExporter.ExportError, .timeOutOfRange)
        }
    }

    func testPositiveIntervalLostByRoundingReportsUsefulError() {
        XCTAssertThrowsError(try SubtitleExporter.srt(primary: SubtitleTrack(cues: [cue(1, 1.0001, "Too brief")]), secondary: empty)) {
            XCTAssertEqual($0 as? SubtitleExporter.ExportError, .submillisecondCue)
            let guidance = ($0 as? BilingualError)?.message
            XCTAssertTrue(guidance?.english.contains("rounding to milliseconds") == true)
            XCTAssertTrue(guidance?.english.contains("Adjust its timestamps") == true)
            XCTAssertTrue(guidance?.chinese.contains("毫秒舍入后没有时长") == true)
            XCTAssertTrue(guidance?.chinese.contains("调整时间") == true)
        }
    }

    func testExportDoesNotMutateEitherInputTrack() throws {
        let primary = SubtitleTrack(cues: [cue(4, 5, "Later", id: 4), cue(0, 2, "First", id: 2)])
        let secondary = SubtitleTrack(cues: [cue(1, 3, "译文", id: 8)])
        let beforePrimary = primary.cues
        let beforeSecondary = secondary.cues
        _ = try SubtitleExporter.srt(primary: primary, secondary: secondary, primaryOffset: 0.25, secondaryOffset: -0.75)
        XCTAssertEqual(primary.cues, beforePrimary)
        XCTAssertEqual(secondary.cues, beforeSecondary)
    }
}
