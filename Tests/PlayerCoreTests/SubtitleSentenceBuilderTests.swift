import Foundation
import XCTest
@testable import PlayerCore

final class SubtitleSentenceBuilderTests: XCTestCase {
    private func cue(_ id: Int, _ start: Double, _ end: Double, _ text: String) -> SubtitleCue {
        SubtitleCue(id: id, start: start, end: end, text: text)
    }

    func testEmptyTracksAndChineseWithoutEnglish() {
        let empty = SubtitleSentenceBuilder.build(english: [], chinese: [])
        XCTAssertTrue(empty.english.cues.isEmpty && empty.chinese.cues.isEmpty && empty.groups.isEmpty)
        let chineseOnly = SubtitleSentenceBuilder.build(english: [], chinese: [cue(8, 2, 4, "你好\n世界。")])
        XCTAssertEqual(chineseOnly.chinese.cues.first?.text, "你好世界。")
        XCTAssertEqual(chineseOnly.chinese.cues.first?.start, 2)
        XCTAssertEqual(chineseOnly.chinese.cues.first?.end, 4)
        XCTAssertEqual(chineseOnly.unmatchedChineseCueIDs, [8])
    }

    func testFragmentsBecomeSentenceGroupsAndTranslationsKeepTheirOwnRange() {
        let english = [cue(10, 0, 1, "I enjoy"), cue(11, 1, 2, "reading\nbooks."), cue(12, 2, 3, "Try one.")]
        let chinese = [cue(20, 0.1, 0.9, "我\n喜欢"), cue(21, 1.1, 1.9, "读书。"), cue(22, 2.1, 2.9, "试试吧。")]
        let result = SubtitleSentenceBuilder.build(english: english, chinese: chinese)
        XCTAssertEqual(result.english.cues.map(\.text), ["I enjoy reading books.", "Try one."])
        XCTAssertEqual(result.chinese.cues.map(\.text), ["我喜欢读书。", "试试吧。"])
        XCTAssertEqual(result.groups[0].englishCueIDs, [10, 11])
        XCTAssertEqual(result.groups[0].chineseCueIDs, [20, 21])
        XCTAssertEqual(result.chinese.cues[0].start, 0.1)
        XCTAssertEqual(result.chinese.cues[0].end, 1.9)
        XCTAssertEqual(english[1].text, "reading\nbooks.")
        XCTAssertEqual(chinese[0].start, 0.1)
    }

    func testReceivingChineseCannotChangeEnglishGroupingOrIDs() {
        let english = [cue(1, 0, 1, "A short"), cue(2, 1, 2, "sentence."), cue(3, 2, 4, "Another.")]
        let before = SubtitleSentenceBuilder.build(english: english, chinese: [])
        let after = SubtitleSentenceBuilder.build(english: english, chinese: [cue(9, 0, 4, "一条完整译文。")])
        XCTAssertEqual(before.english.cues, after.english.cues)
        XCTAssertEqual(before.groups.map(\.englishCueIDs), after.groups.map(\.englishCueIDs))
        XCTAssertEqual(before.groups.map(\.start), after.groups.map(\.start))
        XCTAssertEqual(before.groups.map(\.end), after.groups.map(\.end))
    }

    func testMultipleSentencesInsideOneCueKeepTheirOnlyRealInterval() {
        let result = SubtitleSentenceBuilder.build(english: [cue(5, 3, 9, "Hello. Goodbye! Still here?")], chinese: [])
        XCTAssertEqual(result.english.cues.count, 1)
        XCTAssertEqual(result.english.cues[0].start, 3)
        XCTAssertEqual(result.english.cues[0].end, 9)
        XCTAssertEqual(result.english.cues[0].text, "Hello. Goodbye! Still here?")
    }

    func testGapAndLimitsBreakOnlyAtCueBoundaries() {
        let gap = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "before"), cue(1, 3, 4, "after")], chinese: [])
        XCTAssertEqual(gap.english.cues.map(\.text), ["before", "after"])
        let duration = SubtitleSentenceBuilder.build(english: [cue(0, 0, 5, "one"), cue(1, 5, 10, "two"), cue(2, 10, 14, "three")], chinese: [])
        XCTAssertEqual(duration.english.cues.map(\.text), ["one two", "three"])
        XCTAssertEqual(duration.english.cues.map(\.end), [10, 14])
        let characters = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "one two"), cue(1, 1, 2, "three")], chinese: [],
            options: .init(maximumEnglishCharacters: 10))
        XCTAssertEqual(characters.english.cues.map(\.text), ["one two", "three"])
    }

    func testAnOverlongSingleCueIsNotSplitUsingInventedWordTimes() {
        let text = String(repeating: "word ", count: 50).trimmingCharacters(in: .whitespaces)
        let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 20, text), cue(1, 20, 21, "next")], chinese: [])
        XCTAssertEqual(result.english.cues.count, 2)
        XCTAssertEqual(result.english.cues[0].end, 20)
        XCTAssertEqual(result.english.cues[0].text, text)
    }

    func testAbbreviationsInitialsAndDecimalsDoNotPrematurelyEndSentences() {
        for pair in [("Dr.", "Stone arrived."), ("For example, e.g.", "small tools."), ("The U.S.", "team won."), ("J.", "Smith spoke.")] {
            let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, pair.0), cue(1, 1, 2, pair.1)], chinese: [])
            XCTAssertEqual(result.english.cues.count, 1, pair.0)
        }
        let decimal = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "The value is 3."), cue(1, 1, 2, "14 today.")], chinese: [])
        XCTAssertEqual(decimal.english.cues.map(\.text), ["The value is 3.14 today."])
        let complete = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "It is 3.14."), cue(1, 1, 2, "Done.")], chinese: [])
        XCTAssertEqual(complete.english.cues.count, 2)
        let terminalAbbreviation = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "I live in the U.S."), cue(1, 1, 2, "It is home.")], chinese: [])
        XCTAssertEqual(terminalAbbreviation.english.cues.count, 2)
    }

    func testClosingQuotesAndCJKSentencePunctuationEndGroups() {
        for ending in ["She said, \"Go.\"", "结束。", "Really?", "Go!", "Wait..."] {
            let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, ending), cue(1, 1, 2, "Next part")], chinese: [])
            XCTAssertEqual(result.english.cues.count, 2, ending)
        }
    }

    func testSpeakerAndMusicBoundariesArePreserved() {
        let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "ALICE: Good"), cue(1, 1, 2, "morning"),
            cue(2, 2, 3, ">> BOB: Hello"), cue(3, 3, 4, "[Music]"), cue(4, 4, 5, "afterwards")], chinese: [])
        XCTAssertEqual(result.english.cues.map(\.text), ["ALICE: Good morning", ">> BOB: Hello", "[Music]", "afterwards"])
        XCTAssertEqual(SubtitleSentenceBuilder.normalizedText("ALICE: Hello\n>> BOB: Hi"), "ALICE: Hello\n>> BOB: Hi")
        XCTAssertEqual(SubtitleSentenceBuilder.normalizedText("before\n[Music]\nafter"), "before\n[Music]\nafter")
    }

    func testWhitespaceReflowCJKMixedTextPunctuationAndHyphenation() {
        let cases = [
            (" Good\n morning  everyone. ", "Good morning everyone."),
            ("你好\n，\n世界。", "你好，世界。"),
            ("おはよう\nございます。", "おはようございます。"),
            ("안녕하세요\n반갑습니다.", "안녕하세요 반갑습니다."),
            ("学习\nSwift\n很好。", "学习 Swift 很好。"),
            ("A well-\nknown example.", "A well-known example."),
            ("Read (\nthis\n) carefully.", "Read (this) carefully.")
        ]
        for (input, expected) in cases { XCTAssertEqual(SubtitleSentenceBuilder.normalizedText(input), expected) }
    }

    func testCompactSpeakerLabelsAndInternalEventsStillCreateBoundaries() {
        for marker in ["ALICE:Hello", "[Alice] Hello", "张三：你好", "words\n[Music]\nwords"] {
            let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "before"), cue(1, 1, 2, marker)], chinese: [])
            XCTAssertEqual(result.english.cues.count, 2, marker)
        }
    }

    func testChineseCueGetsOneBestOverlapAndNeverRepeatsAcrossGroups() {
        let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 2, "First."), cue(1, 2, 4, "Second.")],
                                                   chinese: [cue(20, 0, 4, "一条译文，不拆分。")])
        XCTAssertEqual(result.chinese.cues.count, 1)
        XCTAssertEqual(result.chinese.cues[0].id, 1)
        XCTAssertEqual(result.chinese.cues[0].start, 0)
        XCTAssertEqual(result.chinese.cues[0].end, 4)
        XCTAssertEqual(result.groups[0].chineseCueIDs, [])
        XCTAssertEqual(result.groups[1].chineseCueIDs, [20])
        let greatest = SubtitleSentenceBuilder.build(english: [cue(0, 0, 1, "Brief."), cue(1, 1, 4, "Longer.")],
                                                     chinese: [cue(2, 0.5, 3, "译文。")])
        XCTAssertEqual(greatest.chinese.cues[0].id, 1)
        let gapTie = SubtitleSentenceBuilder.build(english: [cue(0, 0, 4, "First."), cue(1, 6, 10, "Second.")],
                                                   chinese: [cue(2, 0, 10, "译文。")])
        XCTAssertEqual(gapTie.chinese.cues[0].id, 0)
    }

    func testUnmatchedChineseKeepsSourceRangeAndEmptyGroupsStayEmpty() {
        let result = SubtitleSentenceBuilder.build(english: [cue(0, 2, 3, "English."), cue(1, 4, 5, "Untranslated.")],
            chinese: [cue(8, 0, 1, "提前出现。"), cue(9, 2.1, 2.9, "英文。"), cue(10, 6, 7, "之后出现。")])
        XCTAssertEqual(result.unmatchedChineseCueIDs, [8, 10])
        XCTAssertEqual(result.chinese.cues.map(\.start), [0, 2.1, 6])
        XCTAssertEqual(result.chinese.cues.map(\.end), [1, 2.9, 7])
        XCTAssertTrue(result.chinese.activeCues(at: 4.5).isEmpty)
    }

    func testOnlyCompleteSameAnchorDuplicatesAreCollapsed() {
        let duplicate = SubtitleSentenceBuilder.build(english: [cue(7, 0, 1, "Run."), cue(8, 0, 2, "Run.")], chinese: [])
        XCTAssertEqual(duplicate.english.cues.map(\.text), ["Run."])
        XCTAssertEqual(duplicate.groups[0].englishCueIDs, [7, 8])
        XCTAssertEqual(duplicate.english.cues[0].end, 2)
        let repeated = SubtitleSentenceBuilder.build(english: [cue(1, 0, 2, "no"), cue(2, 1, 3, "no")], chinese: [])
        XCTAssertEqual(repeated.english.cues.map(\.text), ["no no"])
        let adjacent = SubtitleSentenceBuilder.build(english: [cue(1, 0, 1, "Go!"), cue(2, 1, 2, "Go!")], chinese: [])
        XCTAssertEqual(adjacent.english.cues.map(\.text), ["Go!", "Go!"])
        let partial = SubtitleSentenceBuilder.build(english: [cue(1, 0, 2, "I can"), cue(2, 1, 3, "I can help.")], chinese: [])
        XCTAssertEqual(partial.english.cues.map(\.text), ["I can I can help."])
    }

    func testOverlapsSortStablyAndInvalidOrEmptyCuesAreExcluded() {
        let result = SubtitleSentenceBuilder.build(english: [cue(2, 1, 3, "again"), cue(1, 0, 2, "hello"),
            cue(3, -.infinity, 2, "bad"), cue(4, 3, 3, "bad"), cue(5, 3, 4, " \n ")], chinese: [])
        XCTAssertEqual(result.english.cues.map(\.text), ["hello again"])
        XCTAssertEqual(result.english.cues[0].start, 0)
        XCTAssertEqual(result.english.cues[0].end, 3)
        XCTAssertEqual(result.groups[0].englishCueIDs, [1, 2])
    }

    func testInvalidOptionsHaveBoundedDefaults() {
        let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 6, "one"), cue(1, 6, 12, "two"), cue(2, 12, 13, "three")], chinese: [],
            options: .init(maximumDuration: .nan, maximumEnglishCharacters: 0, maximumGap: -.infinity))
        XCTAssertEqual(result.english.cues.map(\.text), ["one two", "three"])
    }

    func testOverlapCoverageUsesMaximumEndWhenCheckingGaps() {
        let result = SubtitleSentenceBuilder.build(english: [cue(0, 0, 10, "We"), cue(1, 1, 2, "are"), cue(2, 11, 12, "ready.")], chinese: [])
        XCTAssertEqual(result.english.cues.map(\.text), ["We are ready."])
        XCTAssertEqual(result.english.cues[0].end, 12)
    }

    func testIndependentlyShiftedTracksKeepTheirRespectiveClocks() {
        let english = [cue(0, 10, 14, "One sentence.")]
        let later = SubtitleSentenceBuilder.build(english: english, chinese: [cue(1, 10.5, 14.5, "一句译文。")])
        XCTAssertEqual(later.english.cues[0].start, 10)
        XCTAssertEqual(later.english.cues[0].end, 14)
        XCTAssertEqual(later.chinese.cues[0].start, 10.5)
        XCTAssertEqual(later.chinese.cues[0].end, 14.5)
        XCTAssertEqual(later.english.cues[0].id, later.chinese.cues[0].id)
        let earlier = SubtitleSentenceBuilder.build(english: english, chinese: [cue(1, 9.5, 13.5, "一句译文。")])
        XCTAssertEqual(earlier.chinese.cues[0].start, 9.5)
        XCTAssertEqual(earlier.chinese.cues[0].end, 13.5)
        let englishShifted = SubtitleSentenceBuilder.build(english: [cue(0, 13, 17, "One sentence.")],
                                                           chinese: [cue(1, 10.5, 14.5, "一句译文。")])
        XCTAssertEqual(englishShifted.chinese.cues[0].start, 10.5)
        XCTAssertEqual(englishShifted.chinese.cues[0].end, 14.5)
    }
}
