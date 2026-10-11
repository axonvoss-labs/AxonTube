import SwiftUI
import AppKit
import PlayerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var openFiles: (([URL]) -> Void)?
    static var pendingURLs: [URL] = []
    static var willExit: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let handler = Self.openFiles { handler(urls) }
        else { Self.pendingURLs.append(contentsOf: urls) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { Self.willExit?() }
}

@main
struct AxonTubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = PlayerModel()
    @AppStorage(L10n.preferenceKey) private var interfaceLanguage = AppLanguage.english.rawValue

    private var playbackReady: Bool { model.hasMedia && model.isReady }
    private var practiceReady: Bool { playbackReady && !model.learningTrack.cues.isEmpty }

    var body: some Scene {
        WindowGroup("AxonTube", id: "player") {
            PlayerView(model: model)
                .frame(minWidth: 1160, minHeight: model.youtube == nil ? 720 : 800)
                .environment(\.locale, Locale(identifier: interfaceLanguage))
                .environment(\.layoutDirection, L10n.language.isRightToLeft ? .rightToLeft : .leftToRight)
                .preferredColorScheme(.dark)
                .onOpenURL { model.openURLs([$0]) }
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.text("Open Video…", "打开视频…"), action: model.chooseVideo).keyboardShortcut("o")
                Button(L10n.text("Open YouTube Link…", "打开 YouTube 链接…")) { model.showYouTubeSheet = true }.keyboardShortcut("k")
                Button(L10n.text("Save Video", "保存视频"), action: model.saveVideo)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!model.canSaveVideo)
                Button(L10n.text("Open Primary Subtitles…", "打开第一字幕…")) { model.chooseSubtitle(slot: 0) }.keyboardShortcut("1", modifiers: [.command])
                Button(L10n.text("Open Secondary Subtitles…", "打开第二字幕…")) { model.chooseSubtitle(slot: 1) }.keyboardShortcut("2", modifiers: [.command])
                Divider()
                Button(L10n.text("Export Bilingual Subtitles…", "导出双语字幕…"), action: model.exportBilingualSubtitles)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!model.canExportSubtitles)
            }
            CommandMenu(L10n.text("Study", "学习播放")) {
                Button(model.isPlaying ? L10n.text("Pause", "暂停") : L10n.text("Play", "播放"), action: model.togglePlayback)
                    .keyboardShortcut(.space, modifiers: []).disabled(!playbackReady)
                Button(L10n.text("Previous Sentence", "上一句"), action: model.previousCue)
                    .keyboardShortcut(.leftArrow, modifiers: [.option]).disabled(!practiceReady)
                Button(L10n.text("Next Sentence", "下一句"), action: model.nextCue)
                    .keyboardShortcut(.rightArrow, modifiers: [.option]).disabled(!practiceReady)
                Button(L10n.text("Replay Sentence", "重听当前句"), action: model.replayCue)
                    .keyboardShortcut("r", modifiers: [.command]).disabled(!practiceReady)
                Button(model.loopEnabled ? L10n.text("Stop Sentence Loop", "关闭逐句循环") : L10n.text("Loop Sentence", "循环当前句"), action: model.toggleLoop)
                    .keyboardShortcut("l", modifiers: [.command]).disabled(!practiceReady)
                Divider()
                Button(L10n.text("Back 5 Seconds", "后退 5 秒")) { model.seek(to: model.currentTime - 5) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command]).disabled(!playbackReady)
                Button(L10n.text("Forward 5 Seconds", "前进 5 秒")) { model.seek(to: model.currentTime + 5) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command]).disabled(!playbackReady)
            }
            CommandMenu(L10n.text("Language", "语言")) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                    Button { interfaceLanguage = language.rawValue } label: {
                        if interfaceLanguage == language.rawValue {
                            Label(language.displayName, systemImage: "checkmark")
                        } else { Text(language.displayName) }
                    }
                }
            }
        }
    }
}
