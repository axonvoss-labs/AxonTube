import XCTest
@testable import PlayerCore

final class AppLocalizationTests: XCTestCase {
    func testStoredMessageRetainsBothLanguagesAndArguments() {
        let filename = "lecture 中文.mp4"
        let message = LocalizedText("Loaded \(filename) · 8 cues", "已载入 \(filename) · 8 句")
        XCTAssertEqual(message.resolved(for: .english), "Loaded lecture 中文.mp4 · 8 cues")
        XCTAssertEqual(message.resolved(for: .simplifiedChinese), "已载入 lecture 中文.mp4 · 8 句")
    }

    func testWrappedBilingualErrorPreservesBothVariants() {
        struct Failure: BilingualError {
            let message = LocalizedText("No captions", "暂无字幕")
        }
        let message = LocalizedText("Export failed: ", "导出失败：") + LocalizedText(error: Failure())
        XCTAssertEqual(message.resolved(for: .english), "Export failed: No captions")
        XCTAssertEqual(message.resolved(for: .simplifiedChinese), "导出失败：暂无字幕")
    }

    func testVerbatimContentIsNeverTranslated() {
        let message = LocalizedText(verbatim: "中文 subtitle / user's filename.srt")
        XCTAssertEqual(message.resolved(for: .english), message.resolved(for: .simplifiedChinese))
        XCTAssertTrue(LocalizedText(verbatim: "").isEmpty)
    }

    func testLanguageChoicesIncludeOnlyArabicAndHebrewAsRightToLeft() {
        XCTAssertEqual(AppLanguage.allCases.count, 24)
        XCTAssertEqual(Set(AppLanguage.allCases.map(\.rawValue)).count, 24)
        XCTAssertEqual(Set(AppLanguage.allCases.filter(\.isRightToLeft)), [.arabic, .hebrew])
        XCTAssertEqual(AppLanguage.traditionalChinese.displayName, "繁體中文")
    }

    func testInterpolatedFilenamesRemainVerbatimInEveryInterfaceLanguage() {
        // The separator appears in filenames too; digits and {1} must stay literal.
        // Protecting the count before the filename used to corrupt Traditional Chinese.
        let filename = "简体 · take{1}0.srt"
        let loaded = LocalizedText("Loaded \(filename) · 0 cues", "已载入 \(filename) · 0 句")
        let exported = LocalizedText("Exported 0 cues · \(filename)", "已导出 0 句 · \(filename)")
        for language in AppLanguage.allCases {
            XCTAssertTrue(loaded.resolved(for: language).contains(filename), language.rawValue)
            XCTAssertTrue(exported.resolved(for: language).contains(filename), language.rawValue)
        }
        XCTAssertEqual(loaded.resolved(for: .traditionalChinese), "已載入 \(filename) · 0 句")
        XCTAssertEqual(exported.resolved(for: .traditionalChinese), "已導出 0 句 · \(filename)")
        XCTAssertEqual(loaded.resolved(for: .spanish), "Cargado \(filename) · 0 segmentos")
    }

    func testConcatenationLocalizesThePrefixAndPreservesUserContent() {
        let message = LocalizedText("Play", "播放") + LocalizedText(verbatim: " — 简体中文 {0} Play")
        XCTAssertEqual(message.resolved(for: .spanish), "Reproducir — 简体中文 {0} Play")
        for language in AppLanguage.allCases {
            XCTAssertEqual(LocalizedText(verbatim: "Play").resolved(for: language), "Play")
        }
    }

    func testMenuAliasAndUnknownDiagnosticFallback() {
        XCTAssertEqual(LocalizedText("Open Video…", "打开视频…").resolved(for: .japanese), "動画を開く…")
        XCTAssertEqual(LocalizedText("Interface language", "界面语言").resolved(for: .spanish), "Idioma de la interfaz")
        XCTAssertEqual(LocalizedText("Unknown diagnostic", "未知诊断").resolved(for: .french), "Unknown diagnostic")
    }
}
