import Foundation
import XCTest
@testable import PlayerCore

final class SubtitleTests: XCTestCase {
    func testSRTBOMCRLFMultilineAndMarkup() throws {
        let text = "\u{FEFF}1\r\n00:00:01,250 --> 00:00:03,500\r\n<b>Hello &amp; welcome.</b>\r\n&#x4E2D;&#25991; &lt;literal&gt;<br>Last line\r\n"
        let cues = try SubtitleParser.parse(text, fileExtension: "SRT")
        XCTAssertEqual(cues, [SubtitleCue(id: 0, start: 1.25, end: 3.5, text: "Hello & welcome.\n中文 <literal>\nLast line")])
    }

    func testVTTSettingsIdentifiersCommentsStylesAndShortTimestamps() throws {
        let text = """
        WEBVTT Example
        Kind: captions

        NOTE This is not a cue
        00:00.000 --> 00:20.000
        ignore

        STYLE
        ::cue { color: lime; }

        REGION
        id:lower

        first-identifier
        00:01.125 --> 00:02.750 align:start position:10%
        <v Alex><c.green>Hello</c> <00:01.500>there.</v>

        second-identifier
        00:00:03.000 --> 00:00:05.000
        <i>Second line.</i>
        """
        let cues = try SubtitleParser.parse(text, fileExtension: ".vtt")
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].start, 1.125)
        XCTAssertEqual(cues[0].end, 2.75)
        XCTAssertEqual(cues.map(\.text), ["Hello there.", "Second line."])
    }

    func testInvalidCuesSkippedAndStableOrdering() throws {
        let text = """
        8
        00:00:09,000 --> 00:00:11,000
        Later

        invalid
        00:01:61,000 --> 00:02:09,000
        Invalid seconds

        7
        00:00:05,000 --> 00:00:04,000
        Backwards

        3
        00:00:02,000 --> 00:00:04,000
        First

        3
        00:00:02,000 --> 00:00:04,000
        Same time, source order

        4
        00:00:05,000 --> 00:00:06,000
        <b></b>
        """
        let cues = try SubtitleParser.parse(text, fileExtension: "srt")
        XCTAssertEqual(cues.map(\.id), [0, 1, 2])
        XCTAssertEqual(cues.map(\.text), ["First", "Same time, source order", "Later"])
    }

    func testASSCommaTextOverridesNewlinesAndVectorDrawing() throws {
        let text = #"""
        [Script Info]
        Title: Demo
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.25,0:00:03.50,Default,,0,0,0,,{\an8}{\i1}Hello, friend.{\i0}\NSecond\hline.
        Comment: 0,0:00:03.50,0:00:05.00,Default,,0,0,0,,Comment only
        Dialogue: 0,0:00:05.00,0:00:06.00,Default,,0,0,0,,{\p1}m 0 0 l 100 100{\p0}
        """#
        let cues = try SubtitleParser.parse(text, fileExtension: "ass")
        XCTAssertEqual(cues, [SubtitleCue(id: 0, start: 1.25, end: 3.5, text: "Hello, friend.\nSecond\u{00A0}line.")])
    }

    func testSSAFormatMayReorderFields() throws {
        let cues = try SubtitleParser.parse("""
        [Events]
        Format: End, Start, Style, Text
        Dialogue: 0:00:04.00,0:00:02.00,Default,Older SSA, with commas
        """, fileExtension: "ssa")
        XCTAssertEqual(cues.first?.start, 2)
        XCTAssertEqual(cues.first?.end, 4)
        XCTAssertEqual(cues.first?.text, "Older SSA, with commas")
    }

    func testAdjacentCuesWithoutBlankLines() throws {
        let cues = try SubtitleParser.parse("""
        1
        00:00:00,000 --> 00:00:02,000
        First
        2
        00:00:02,000 --> 00:00:04,000
        Second
        """, fileExtension: "srt")
        XCTAssertEqual(cues.map(\.text), ["First", "Second"])
        let withoutIDs = try SubtitleParser.parse("00:00:00,000 --> 00:00:02,000\nKeep this line\n00:00:02,000 --> 00:00:04,000\nSecond", fileExtension: "srt")
        XCTAssertEqual(withoutIDs.map(\.text), ["Keep this line", "Second"])
    }

    func testInvalidAndUnknownFilesGiveUsefulErrors() {
        XCTAssertThrowsError(try SubtitleParser.parse("1\n00:00:01,000 --> 00:00:01,000\nEmpty interval", fileExtension: "srt")) { error in
            XCTAssertEqual(error as? SubtitleError, .noValidCues("srt"))
            let guidance = (error as? BilingualError)?.message
            XCTAssertTrue(guidance?.english.contains("end time is after its start time") == true)
            XCTAssertTrue(guidance?.chinese.contains("结束时间是否晚于开始时间") == true)
        }
        XCTAssertThrowsError(try SubtitleParser.parse("some data", fileExtension: "txt")) { error in
            XCTAssertEqual(error as? SubtitleError, .unsupportedFormat("txt"))
            let guidance = (error as? BilingualError)?.message
            XCTAssertTrue(guidance?.english.contains("SRT, VTT, ASS, or SSA") == true)
            XCTAssertTrue(guidance?.chinese.contains("SRT、VTT、ASS 或 SSA") == true)
        }
        XCTAssertThrowsError(try SubtitleParser.read(url: URL(string: "https://example.invalid/subtitles.srt")!)) { error in
            XCTAssertEqual(error as? SubtitleError, .nonLocalFile)
            let guidance = (error as? BilingualError)?.message
            XCTAssertTrue(guidance?.english.contains("local subtitle file") == true)
            XCTAssertTrue(guidance?.chinese.contains("本机上的字幕文件") == true)
        }
    }

    func testTrackGapsExclusiveEndsAndLongOverlap() {
        let track = SubtitleTrack(cues: [
            .init(id: 0, start: 1, end: 20, text: "long"),
            .init(id: 1, start: 2, end: 3, text: "short"),
            .init(id: 2, start: 4, end: 5, text: "later short"),
            .init(id: 3, start: 22, end: 25, text: "after gap")
        ])
        XCTAssertEqual(track.activeCues(at: 0), [])
        XCTAssertEqual(track.activeCues(at: 2).map(\.id), [0, 1])
        XCTAssertEqual(track.activeIndex(at: 2), 1)
        XCTAssertEqual(track.activeCues(at: 3).map(\.id), [0])
        XCTAssertEqual(track.activeCues(at: 6).map(\.id), [0])
        XCTAssertEqual(track.activeIndex(at: 6), 0)
        XCTAssertEqual(track.activeCues(at: 20), [])
        XCTAssertEqual(track.activeIndex(at: 21), nil)
        XCTAssertEqual(track.activeCues(at: 22).map(\.id), [3])
        XCTAssertEqual(track.activeCues(at: 25), [])
        XCTAssertEqual(track.activeCues(at: .nan), [])
    }

    func testIndependentTracksUseTimesRatherThanMatchingIndexes() {
        let english = SubtitleTrack(cues: [.init(id: 0, start: 0, end: 3, text: "One"), .init(id: 1, start: 3, end: 6, text: "Two")])
        let chinese = SubtitleTrack(cues: [.init(id: 0, start: 0.25, end: 3.4, text: "一"), .init(id: 1, start: 3.6, end: 6, text: "二")])
        XCTAssertEqual(english.activeIndex(at: 3.2), 1)
        XCTAssertEqual(chinese.activeIndex(at: 3.2), 0)
        XCTAssertEqual(chinese.activeCues(at: 3.5), [])
    }

    func testOverlappingIntervalsForDifferentSubtitleSegmentation() {
        let track = SubtitleTrack(cues: [
            .init(id: 0, start: 0.6, end: 2.8, text: "Delayed translation"),
            .init(id: 1, start: 3.1, end: 4.2, text: "First half"),
            .init(id: 2, start: 4.2, end: 5.8, text: "Second half")
        ])
        XCTAssertEqual(track.overlappingCues(start: 0.5, end: 3).map(\.id), [0])
        XCTAssertEqual(track.overlappingCues(start: 3, end: 6).map(\.id), [1, 2])
        XCTAssertEqual(track.overlappingCues(start: 2.8, end: 3.1), [])
        XCTAssertEqual(track.overlappingCues(start: 5, end: 4), [])
    }

    func testNavigationAtBoundariesMidCueAndGap() {
        let track = SubtitleTrack(cues: [.init(id: 0, start: 1, end: 3, text: "A"), .init(id: 1, start: 5, end: 6, text: "B")])
        XCTAssertNil(track.previousIndex(at: 1))
        XCTAssertEqual(track.previousIndex(at: 2), 0)
        XCTAssertEqual(track.previousIndex(at: 5), 0)
        XCTAssertEqual(track.previousIndex(at: 7), 1)
        XCTAssertEqual(track.nextIndex(at: 0), 0)
        XCTAssertEqual(track.nextIndex(at: 1), 1)
        XCTAssertEqual(track.nextIndex(at: 4), 1)
        XCTAssertNil(track.nextIndex(at: 5))
        XCTAssertNil(track.nextIndex(at: .infinity))
    }

    func testTrackSortsInputAndDiscardsInvalidTimes() {
        let track = SubtitleTrack(cues: [.init(id: 7, start: 5, end: 6, text: "B"), .init(id: 4, start: 1, end: 3, text: "A"), .init(id: 9, start: 3, end: 2, text: "invalid"), .init(id: 10, start: -.infinity, end: 4, text: "invalid")])
        XCTAssertEqual(track.cues.map(\.id), [4, 7])
        XCTAssertEqual(track.activeIndex(at: 2), 0)
    }

    func testReadUTF8UTF16AndGB18030() throws {
        let text = "1\n00:00:01,000 --> 00:00:02,000\n中文与 café\n"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AxonTubeSubtitleTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Test fixtures are newly created, disposable files owned by this test.
        defer { try? FileManager.default.removeItem(at: directory) }
        let encodings: [(String.Encoding, [UInt8])] = [(.utf8, []), (.utf16LittleEndian, [0xFF, 0xFE]), (.utf16BigEndian, [0xFE, 0xFF]), (.utf16LittleEndian, []), (String.Encoding(rawValue: 0x80000632), [])]
        for (index, pair) in encodings.enumerated() {
            let encoded = try XCTUnwrap(text.data(using: pair.0))
            var data = Data(pair.1)
            data.append(encoded)
            let url = directory.appendingPathComponent("fixture-\(index).srt")
            try data.write(to: url)
            XCTAssertEqual(try SubtitleParser.read(url: url).first?.text, "中文与 café", "Encoding \(pair.0.rawValue)")
        }
    }

    func testEntityDecodingPreservesUnknownAndInvalidEntities() throws {
        let cues = try SubtitleParser.parse("1\n00:00:00,000 --> 00:00:01,000\n2 < 3 > 1 &unknown; &#xD800; &amp;lt; &#128512;", fileExtension: "srt")
        XCTAssertEqual(cues.first?.text, "2 < 3 > 1 &unknown; &#xD800; &lt; 😀")
    }
}
