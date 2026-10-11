import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers
import PlayerCore

private enum Palette {
    static let background = Color(red: 0.047, green: 0.062, blue: 0.084)
    static let panel = Color(red: 0.073, green: 0.091, blue: 0.118)
    static let card = Color(red: 0.10, green: 0.125, blue: 0.157)
    static let mint = Color(red: 0.39, green: 0.88, blue: 0.72)
    static let gold = Color(red: 0.98, green: 0.78, blue: 0.45)
    static let muted = Color(red: 0.53, green: 0.59, blue: 0.66)
}

struct PlayerView: View {
    @ObservedObject var model: PlayerModel
    @AppStorage(L10n.preferenceKey) private var interfaceLanguage = AppLanguage.english.rawValue
    @State private var isDropTarget = false
    @State private var showSubtitleSettings = false
    @State private var scrubbing = false
    @State private var scrubPosition = 0.0
    @State private var youtubeMessageHeight: CGFloat = 0

    private var playbackReady: Bool { model.hasMedia && model.isReady }
    private var practiceReady: Bool { playbackReady && !model.learningTrack.cues.isEmpty }
    private var playbackUnavailableHint: String {
        model.hasMedia
            ? L10n.text("Playback is not ready yet.", "视频尚未就绪。")
            : L10n.text("Open a video to enable playback and saving.", "打开视频后即可播放和保存。")
    }
    private var practiceUnavailableHint: String {
        playbackReady ? L10n.text("No subtitles loaded", "尚未载入字幕") : playbackUnavailableHint
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(.white.opacity(0.065)).frame(height: 1)
            HSplitView {
                VStack(spacing: 0) {
                    stage
                    controls
                    learningControls
                }
                .frame(minWidth: 570, maxWidth: .infinity, maxHeight: .infinity)
                sidebar.frame(minWidth: 315, idealWidth: 360, maxWidth: 460)
            }
            footer
        }
        .background(Palette.background)
        .tint(Palette.mint)
        .environment(\.locale, Locale(identifier: interfaceLanguage))
        .environment(\.layoutDirection, L10n.language.isRightToLeft ? .rightToLeft : .leftToRight)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 18).fill(Palette.mint.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.mint, style: StrokeStyle(lineWidth: 2, dash: [8])))
                    .padding(8)
                    .overlay(Label(L10n.text("Drop to open video or subtitles", "松开以打开视频或字幕"), systemImage: "arrow.down.doc.fill").font(.title2.bold()).padding(24).background(.ultraThinMaterial, in: Capsule()))
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTarget) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { continuation in
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                            continuation.resume(returning: data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) })
                        }
                    }
                    if let url { urls.append(url) }
                }
                model.openURLs(urls)
            }
            return true
        }
        .alert(L10n.text("Notice", "提示"), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(L10n.text("OK", "知道了"), role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage?.text ?? "") }
        .sheet(isPresented: $model.showYouTubeSheet) { YouTubeLinkSheet(model: model) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AxonTubeMark().frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("AxonTube").font(.system(size: 20, weight: .bold, design: .rounded)).tracking(-0.4)
                Text(L10n.text("YouTube AI Learning Player", "YouTube AI 学习播放器")).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer()
            Button { model.showYouTubeSheet = true } label: { Label("YouTube", systemImage: "play.rectangle") }
                .buttonStyle(QuietButtonStyle())
                .help(L10n.text("Paste a YouTube video link · ⌘K", "粘贴 YouTube 视频链接 · ⌘K"))
                .accessibilityIdentifier("open-youtube")
            Button(action: model.saveVideo) {
                if model.videoSaver.isSaving {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.mini)
                        Text(L10n.text("Saving video…", "正在保存视频…"))
                    }
                } else {
                    Label(L10n.text("Save Video", "保存视频"), systemImage: "square.and.arrow.down")
                }
            }
                .buttonStyle(QuietButtonStyle(isBusy: model.videoSaver.isSaving))
                .disabled(!model.canSaveVideo)
                .help(model.videoSaver.isSaving ? model.videoSaver.status.text : model.hasMedia
                      ? L10n.text("Save video and synchronized subtitles to a folder", "将视频和同步字幕保存到文件夹")
                      : L10n.text("Open a video before saving.", "请先打开视频，再保存。"))
                .accessibilityIdentifier("save-video")
            Button { showSubtitleSettings.toggle() } label: {
                Label(L10n.text("Subtitles", "字幕设置"), systemImage: showSubtitleSettings ? "checkmark.circle.fill" : "slider.horizontal.3")
            }
                .buttonStyle(QuietButtonStyle(isSelected: showSubtitleSettings))
                .popover(isPresented: $showSubtitleSettings, arrowEdge: .bottom) { subtitleSettings }
                .accessibilityValue(showSubtitleSettings ? L10n.text("On", "开启") : L10n.text("Off", "关闭"))
                .accessibilityIdentifier("subtitle-settings")
            languageMenu
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var languageMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                Button {
                    interfaceLanguage = language.rawValue
                } label: {
                    if interfaceLanguage == language.rawValue {
                        Label(language.displayName, systemImage: "checkmark")
                    } else { Text(language.displayName) }
                }
            }
        } label: {
            Label(L10n.text("Language", "语言"), systemImage: "globe")
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderedButton).controlSize(.large).fixedSize()
        .help(L10n.text("Interface Language", "界面语言"))
        .accessibilityIdentifier("interface-language-menu")
    }

    @ViewBuilder
    private var stage: some View {
        if let controller = model.youtube { youtubeStage(controller) }
        else { localStage }
    }

    private func youtubeStage(_ controller: YouTubeController) -> some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill").foregroundStyle(.red)
                Text(L10n.text("YouTube Playback", "YouTube 在线播放")).font(.system(size: 11, weight: .medium))
                if model.isLoading { ProgressView().controlSize(.mini) }
                Spacer()
                Button(action: model.reloadYouTube) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help(L10n.text("Reload YouTube", "重新载入 YouTube"))
                    .accessibilityLabel(L10n.text("Reload YouTube", "重新载入 YouTube"))
                Button(action: model.openYouTubeInBrowser) { Label(L10n.text("Watch / Sign In via Browser", "在浏览器观看 / 登录"), systemImage: "arrow.up.right.square") }
                    .buttonStyle(QuietButtonStyle(compact: true))
            }.padding(.bottom, 10)
            // Keep the official player, branding, ads and controls unobscured.
            YouTubeSurface(controller: controller).id(ObjectIdentifier(controller))
                .frame(minWidth: 480, minHeight: 270, maxHeight: .infinity)
            if let message = model.youtubeMessage {
                Text(message.text).font(.system(size: 11)).foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Palette.panel)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: YouTubeMessageHeightKey.self, value: geometry.size.height)
                    })
            }
            CaptionPanel(first: model.activeText(slot: 0), second: model.activeText(slot: 1),
                         fontSize: model.subtitleSize,
                         maximumHeight: max(36, min(270, geometry.size.height - 340 - (model.youtubeMessage == nil ? 0 : youtubeMessageHeight))),
                         placeholder: model.learningTrack.cues.isEmpty ? (model.youtubeCaptions.isFetching ? L10n.text("Preparing bilingual subtitles…", "正在准备双语字幕…") : L10n.text("Your subtitles will appear here", "字幕会显示在这里")) : L10n.text("Bilingual captions will appear here as the video plays", "双语字幕会在这里随视频显示"))
                .background(Palette.panel)
        }.padding(.horizontal, 20).padding(.top, 16)
            .onPreferenceChange(YouTubeMessageHeightKey.self) { youtubeMessageHeight = $0 }
        }
    }

    private var localStage: some View {
        ZStack {
            Color.black
            if model.mediaURL != nil {
                VideoSurface(player: model.player)
                VStack {
                    HStack {
                        Text(model.displayName).font(.system(size: 11, weight: .medium)).lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                        Spacer()
                        Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                            .buttonStyle(.plain).padding(9).background(.black.opacity(0.5), in: Circle())
                            .help(L10n.text("Enter or leave full screen", "进入或退出全屏"))
                            .accessibilityLabel(L10n.text("Toggle Full Screen", "切换全屏"))
                    }
                    Spacer(minLength: 12)
                    CaptionPanel(first: model.activeText(slot: 0), second: model.activeText(slot: 1),
                                 fontSize: model.subtitleSize, maximumHeight: 260,
                                 overVideo: true)
                        .padding(.bottom, 20)
                }
                .padding(16)
                if model.isLoading { ProgressView(L10n.text("Opening…", "正在打开…")).padding(20).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            } else {
                welcome
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.07)))
        .padding(.horizontal, 20).padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("video-stage")
    }

    private var welcome: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.055, green: 0.13, blue: 0.15), Palette.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    ZStack {
                        Circle().fill(Palette.mint.opacity(0.04)).frame(width: 370, height: 370).offset(x: -170, y: -100)
                        Circle().stroke(Palette.mint.opacity(0.09), lineWidth: 1).frame(width: 460, height: 460).offset(x: -170, y: -100)
                    }.allowsHitTesting(false)
                }
            GeometryReader { geometry in
                let compact = geometry.size.height < 470
                ScrollView(.vertical) {
                    VStack(spacing: compact ? 11 : 16) {
                        HStack(spacing: 6) {
                            Circle().fill(Palette.mint).frame(width: 5, height: 5)
                            Text(L10n.text("LANGUAGES OPEN WORLDS", "学会语言 · 看懂世界"))
                                .font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(Palette.mint)
                        }
                        if !compact { AxonTubeMark().frame(width: 66, height: 66) }
                        Text(L10n.text("Learn languages faster.\nExplore a world of knowledge.", "更快学语言，\n看懂天下知识。"))
                            .font(.system(size: compact ? 27 : 30, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("marketing-headline")
                        Text(L10n.text("Turn videos into language practice and new ideas.", "从喜欢的视频出发，练语言、学知识、拓眼界。"))
                            .font(.system(size: 13)).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.text("24 interface languages · Multilingual subtitles", "24 种界面语言 · 多语字幕学习"))
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.mint)
                            .padding(.horizontal, 13).padding(.vertical, 6)
                            .background(Palette.mint.opacity(0.075), in: Capsule())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("marketing-badge")
                        Button { model.showYouTubeSheet = true } label: {
                            Label(L10n.text("Open YouTube", "打开 YouTube"), systemImage: "play.rectangle")
                        }.buttonStyle(MintButtonStyle()).padding(.top, compact ? 2 : 5)
                        Text(L10n.text("English + Traditional Chinese subtitles download automatically in about 1–2 minutes.", "英语和繁体中文字幕会自动下载，约需 1–2 分钟。"))
                            .font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(compact ? 23 : 28)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                Text(timeLabel(scrubbing ? scrubPosition : model.currentTime)).monospacedDigit().frame(width: 49, alignment: .leading)
                Slider(value: Binding(get: { scrubbing ? scrubPosition : model.currentTime }, set: {
                    scrubPosition = $0
                    if !scrubbing { model.seek(to: $0) }
                }), in: 0...max(model.duration, 1)) { editing in
                    if editing { scrubPosition = model.currentTime; scrubbing = true }
                    else { model.seek(to: scrubPosition); scrubbing = false }
                }
                .disabled(!playbackReady || model.duration <= 0)
                .accessibilityLabel(L10n.text("Playback position", "播放进度"))
                .accessibilityIdentifier("playback-seek")
                Text(timeLabel(model.duration)).monospacedDigit().frame(width: 49, alignment: .trailing)
            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack(spacing: 17) {
                Button { model.seek(to: model.currentTime - 5) } label: { Image(systemName: "gobackward.5").font(.system(size: 19)) }
                    .buttonStyle(TransportButtonStyle()).disabled(!playbackReady)
                    .help(playbackReady ? L10n.text("Back 5 seconds · ⌘←", "后退 5 秒 · ⌘←") : playbackUnavailableHint)
                    .accessibilityLabel(L10n.text("Back 5 Seconds", "后退 5 秒"))
                    .accessibilityIdentifier("playback-back")
                Button(action: model.togglePlayback) {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                }
                .buttonStyle(TransportButtonStyle(prominent: true)).disabled(!playbackReady)
                .accessibilityLabel(model.isPlaying ? L10n.text("Pause", "暂停") : L10n.text("Play", "播放"))
                .accessibilityIdentifier("playback-toggle")
                .help(playbackReady ? L10n.text("Play / Pause · Space", "播放 / 暂停 · 空格") : playbackUnavailableHint)
                Button { model.seek(to: model.currentTime + 5) } label: { Image(systemName: "goforward.5").font(.system(size: 19)) }
                    .buttonStyle(TransportButtonStyle()).disabled(!playbackReady)
                    .help(playbackReady ? L10n.text("Forward 5 seconds · ⌘→", "前进 5 秒 · ⌘→") : playbackUnavailableHint)
                    .accessibilityLabel(L10n.text("Forward 5 Seconds", "前进 5 秒"))
                    .accessibilityIdentifier("playback-forward")
                Spacer()
                Menu {
                    ForEach(model.playbackRates, id: \.self) { rate in
                        Button { model.setSpeed(rate) } label: {
                            if model.speed == rate { Label(String(format: "%g×", rate), systemImage: "checkmark") }
                            else { Text(String(format: "%g×", rate)) }
                        }
                    }
                } label: {
                    Text(String(format: L10n.text("%g× Speed", "%g× 倍速"), model.speed)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
                .menuStyle(.borderedButton).controlSize(.large).fixedSize().disabled(!playbackReady)
                .help(playbackReady ? L10n.text("Adjust playback speed", "调整播放速度") : playbackUnavailableHint)
                .accessibilityIdentifier("playback-rate")
                Image(systemName: model.volume == 0 ? "speaker.slash" : "speaker.wave.2").foregroundStyle(Palette.muted.opacity(playbackReady ? 1 : 0.5))
                Slider(value: Binding(get: { model.volume }, set: { model.setVolume($0) }), in: 0...1)
                    .frame(width: 80).disabled(!playbackReady).accessibilityLabel(L10n.text("Volume", "音量"))
                    .accessibilityIdentifier("playback-volume")
            }
            if !playbackReady {
                Label(playbackUnavailableHint, systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("playback-unavailable-hint")
            }
        }.padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 18)
    }

    private var learningControls: some View {
        HStack(spacing: 10) {
            Label(L10n.text("Sentence Practice", "逐句练习"), systemImage: "waveform").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
            Spacer(minLength: 4)
            Button(action: model.previousCue) { Label(L10n.text("Previous", "上一句"), systemImage: "backward.end") }
                .help(practiceReady ? "⌥←" : practiceUnavailableHint).accessibilityIdentifier("practice-previous")
            Button(action: model.replayCue) { Label(L10n.text("Replay", "重听"), systemImage: "arrow.counterclockwise") }
                .help(practiceReady ? "⌘R" : practiceUnavailableHint).accessibilityIdentifier("practice-repeat")
            Button(action: model.nextCue) { Label(L10n.text("Next", "下一句"), systemImage: "forward.end") }
                .help(practiceReady ? "⌥→" : practiceUnavailableHint).accessibilityIdentifier("practice-next")
            Button(action: model.toggleLoop) {
                HStack(spacing: 6) {
                    Label(model.loopEnabled ? L10n.text("Looping", "循环中") : L10n.text("Loop Sentence", "单句循环"), systemImage: "repeat.1")
                    if model.loopEnabled { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                }
            }
            .buttonStyle(QuietButtonStyle(compact: true, isSelected: model.loopEnabled))
            .help(practiceReady ? L10n.text("⌘L · Click another sentence to change the loop", "⌘L · 开启后点击其他字幕可切换循环句") : practiceUnavailableHint)
            .accessibilityValue(model.loopEnabled ? L10n.text("On", "开启") : L10n.text("Off", "关闭"))
            .accessibilityIdentifier("practice-loop")
        }
        .buttonStyle(QuietButtonStyle(compact: true))
        .disabled(!practiceReady)
        .padding(.horizontal, 20).padding(.vertical, 15)
        .background(.white.opacity(0.022))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.text("Subtitles", "字幕列表")).font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(L10n.text("\(model.learningTrack.cues.count) cues", "\(model.learningTrack.cues.count) 句")).font(.system(size: 11)).foregroundStyle(Palette.muted)
                Button { model.followCurrent.toggle() } label: {
                    HStack(spacing: 5) {
                        Label(L10n.text("Follow", "跟随"), systemImage: "scope")
                        if model.followCurrent { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                    }
                }
                    .buttonStyle(QuietButtonStyle(compact: true, isSelected: model.followCurrent))
                    .disabled(model.learningTrack.cues.isEmpty)
                    .help(model.learningTrack.cues.isEmpty ? L10n.text("No subtitles loaded", "尚未载入字幕") : L10n.text("Follow the current sentence", "跟随当前句滚动"))
                    .accessibilityLabel(L10n.text("Follow Current Sentence", "跟随当前句"))
                    .accessibilityValue(model.followCurrent ? L10n.text("On", "开启") : L10n.text("Off", "关闭"))
                    .accessibilityIdentifier("subtitle-follow")
            }.padding(.horizontal, 19).padding(.top, 23).padding(.bottom, 16)
            CaptionLanguageControls(model: model, link: model.youtube?.link)
                .padding(.horizontal, 19).padding(.bottom, 16)
            Button(action: model.exportBilingualSubtitles) {
                Label(model.isExportingSubtitles ? L10n.text("Exporting…", "正在导出…") : L10n.text("Export Bilingual Subtitles…", "导出双语字幕…"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(QuietButtonStyle(compact: true))
            .disabled(!model.canExportSubtitles)
            .help(model.canExportSubtitles ? L10n.text("Export as SRT, Word or TXT · Original followed by translation · ⇧⌘E", "导出为 SRT、Word 或 TXT · 原文在上、译文在下 · ⇧⌘E") : model.isExportingSubtitles ? L10n.text("Exporting…", "正在导出…") : L10n.text("No subtitles loaded", "尚未载入字幕"))
            .accessibilityIdentifier("subtitle-export")
            .padding(.horizontal, 19).padding(.bottom, 14)
            if model.youtube != nil && (model.youtubeCaptions.isFetching || !model.youtubeCaptions.status.isEmpty) {
                HStack(alignment: .top, spacing: 8) {
                    if model.youtubeCaptions.isFetching { ProgressView().controlSize(.small) }
                    Text(model.youtubeCaptions.status.text)
                        .foregroundStyle(model.youtubeCaptions.error == nil ? Palette.muted : Palette.gold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !model.youtubeCaptions.isFetching && model.youtubeCaptions.error != nil {
                        Button(L10n.text("Retry", "重试"), action: model.fetchYouTubeCaptions)
                            .buttonStyle(.link)
                    }
                }.font(.system(size: 11)).lineSpacing(3).padding(.horizontal, 19).padding(.bottom, 8)
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField(L10n.text("Search subtitles", "搜索字幕内容"), text: $model.search).textFieldStyle(.plain).font(.system(size: 12))
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) }
                        .buttonStyle(.plain).accessibilityLabel(L10n.text("Clear Search", "清除搜索"))
                }
            }.padding(11).background(Palette.background, in: RoundedRectangle(cornerRadius: 9)).padding(17)
            if model.learningTrack.cues.isEmpty {
                GeometryReader { geometry in
                    ScrollView {
                        subtitleEmpty.frame(minHeight: geometry.size.height)
                    }
                }
            }
            else { subtitleList }
        }
        .background(Palette.panel)
    }

    private func subtitleName(slot: Int) -> String {
        model.slots[slot].displayName.isEmpty ? L10n.text("No subtitles loaded", "尚未载入字幕") : model.slots[slot].displayName
    }

    private var subtitleEmpty: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: "text.bubble").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.mint.opacity(0.8))
            Text(model.youtubeCaptions.isFetching
                 ? L10n.text("Preparing bilingual subtitles…", "正在准备双语字幕…")
                 : model.youtubeCaptions.error != nil
                 ? L10n.text("Subtitles unavailable", "字幕暂不可用")
                 : L10n.text("Your subtitles will appear here", "字幕会显示在这里"))
                .font(.system(size: 19, weight: .medium))
            if model.youtube == nil {
                Text(L10n.text("Open a YouTube video. Subtitles download automatically.", "打开 YouTube 视频，字幕会自动下载。"))
                    .font(.system(size: 13)).lineSpacing(5).foregroundStyle(Palette.muted)
            }
            Spacer()
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filteredCues: [SubtitleCue] {
        let query = model.search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? model.learningTrack.cues : model.learningTrack.cues.filter { $0.text.localizedCaseInsensitiveContains(query) || model.pairedText(for: $0).localizedCaseInsensitiveContains(query) }
    }

    private var subtitleList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(filteredCues) { cue in
                        subtitleRow(cue).id(cue.id)
                    }
                    if filteredCues.isEmpty {
                        Text(L10n.text("No matching sentences", "没有匹配的句子")).font(.system(size: 12)).foregroundStyle(Palette.muted).padding(.top, 35)
                    }
                }.padding(.horizontal, 12).padding(.bottom, 18)
            }
            .onChange(of: model.currentCue?.id) { _, id in
                guard model.followCurrent, model.search.isEmpty, let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
            }
            .onChange(of: model.live.transcript.captions.last?.id) { _, id in
                guard model.live.enabled, model.followCurrent, model.search.isEmpty, let id else { return }
                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private func subtitleRow(_ cue: SubtitleCue) -> some View {
        let active = model.currentCue?.id == cue.id || (model.live.running && model.live.latestEnglish == cue.text)
        let paired = model.pairedText(for: cue)
        return Button { model.playCue(cue) } label: {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(active ? Palette.mint : .clear).frame(width: 3)
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(timeLabel(max(0, cue.start + model.learningOffset))).font(.system(size: 10, design: .monospaced))
                        Spacer()
                        if model.live.enabled, model.live.transcript.captions.first(where: { $0.id == cue.id })?.isFinal == false {
                            Text(L10n.text("Listening…", "听写中…")).font(.system(size: 10))
                        }
                        if model.loopEnabled && model.loopCueID == cue.id { Image(systemName: "repeat.1").font(.system(size: 10)) }
                        else if active { Image(systemName: "waveform").font(.system(size: 10)) }
                    }.foregroundStyle(active ? Palette.mint : Palette.muted)
                    Text(cue.text).font(.system(size: model.subtitleListSize, weight: active ? .medium : .regular)).foregroundStyle(active ? .white : .white.opacity(0.80)).lineSpacing(4).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if !paired.isEmpty { Text(paired).font(.system(size: max(11, model.subtitleListSize - 1))).foregroundStyle(Palette.gold.opacity(0.85)).lineSpacing(3).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, 12).padding(.leading, 8).padding(.trailing, 13)
                .background(active ? Palette.mint.opacity(0.075) : .white.opacity(0.018), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(active ? Palette.mint.opacity(0.20) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(L10n.text("Copy Original", "复制原文")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cue.text, forType: .string) }
            if !paired.isEmpty {
                Button(L10n.text("Copy Bilingual Text", "复制双语文本")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cue.text + "\n" + paired, forType: .string) }
            }
            Button(L10n.text("Play from Here", "从这句播放")) { model.playCue(cue) }
        }
    }

    private var subtitleSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("Subtitle Settings", "字幕设置")).font(.headline)
            ForEach(0..<2) { slot in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(slot == 0 ? L10n.text("First subtitle", "第一字幕") : L10n.text("Second subtitle", "第二字幕")).foregroundStyle(slot == 0 ? Palette.mint : Palette.gold)
                        Spacer()
                        Toggle(L10n.text("Show on Video", "画面显示"), isOn: $model.slots[slot].isVisible).toggleStyle(.checkbox)
                    }.font(.system(size: 12, weight: .medium))
                    Text(subtitleName(slot: slot)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    HStack {
                        Text(L10n.text("Timing offset", "时间偏移")).font(.system(size: 11))
                        Spacer()
                        Button { model.slots[slot].offset -= 0.1 } label: { Image(systemName: "minus") }
                            .accessibilityLabel(L10n.text("Show subtitles 0.1 seconds earlier", "字幕提前 0.1 秒"))
                        Text(String(format: L10n.text("%+.1f s", "%+.1f 秒"), model.slots[slot].offset)).font(.system(size: 12, design: .monospaced)).frame(width: 72)
                        Button { model.slots[slot].offset += 0.1 } label: { Image(systemName: "plus") }
                            .accessibilityLabel(L10n.text("Show subtitles 0.1 seconds later", "字幕延后 0.1 秒"))
                        Button(L10n.text("Reset", "重置")) { model.slots[slot].offset = 0 }
                    }.disabled(model.live.enabled)
                }
            }
            Divider()
            HStack {
                Text(L10n.text("Caption size", "画面字幕字号")).font(.system(size: 12)).frame(width: 84, alignment: .leading)
                Slider(value: $model.subtitleSize, in: 16...48, step: 1).accessibilityLabel(L10n.text("Caption size", "画面字幕字号"))
                Text("\(Int(model.subtitleSize))").monospacedDigit().font(.system(size: 12)).frame(width: 24)
            }
            HStack {
                Text(L10n.text("List size", "列表字号")).font(.system(size: 12)).frame(width: 84, alignment: .leading)
                Slider(value: $model.subtitleListSize, in: 12...24, step: 1).accessibilityLabel(L10n.text("List size", "列表字号"))
                Text("\(Int(model.subtitleListSize))").monospacedDigit().font(.system(size: 12)).frame(width: 24)
            }
            Toggle(L10n.text("Group by Sentence", "按句整理"), isOn: $model.sentenceMode).toggleStyle(.checkbox).disabled(model.live.enabled)
            Text(L10n.text("Merge consecutive cues and smooth awkward line breaks. Turn off to see original segments. Text size and grouping preferences are saved without changing subtitle files.", "合并连续时间片，整理生硬换行；关闭可查看原始分段。字号与整理偏好会自动保存，不修改字幕文件。"))
                .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            Text(L10n.text("Positive offsets delay subtitles; negative offsets show them earlier. Adjust each track separately. ASS displays text without visual effects.", "正数让字幕延后，负数让字幕提前。两条字幕轨道可分别校准；ASS 只显示文本，不渲染特效。"))
                .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            if model.youtube != nil {
                Text(L10n.text("Caption size controls the bilingual text below the video. YouTube’s own CC appearance is managed inside its player.", "画面字号控制视频下方的双语字幕；YouTube 视频内部的 CC 由其播放器设置控制。"))
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            }
        }.padding(22).frame(width: 440)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(model.isConverting || model.videoSaver.isSaving ? Palette.gold : Palette.mint).frame(width: 5, height: 5)
            Text(model.videoSaver.isSaving || model.videoSaver.error != nil ? model.videoSaver.status.text : model.notice.text)
                .lineLimit(1).help(model.videoSaver.isSaving || model.videoSaver.error != nil ? model.videoSaver.status.text : model.notice.text)
            if model.videoSaver.isSaving {
                if let progress = model.videoSaver.progress {
                    ProgressView(value: progress).frame(width: 75)
                    Text("\(Int(progress * 100))%")
                } else { ProgressView().controlSize(.mini) }
                Button(L10n.text("Cancel", "取消")) {
                    model.videoSaver.cancel()
                    model.notice = model.videoSaver.status
                }.buttonStyle(.link)
            }
            if let directory = model.videoSaver.outputDirectory {
                Button(L10n.text("Show Folder", "显示文件夹")) { NSWorkspace.shared.open(directory) }.buttonStyle(.link)
            }
            if model.isConverting {
                if let progress = model.conversionProgress { ProgressView(value: progress).frame(width: 75); Text("\(Int(progress * 100))%") }
                else { ProgressView().controlSize(.mini) }
                Button(L10n.text("Cancel", "取消"), action: model.cancelConversion).buttonStyle(.link)
            }
            if let converted = model.lastConvertedURL {
                Button(L10n.text("Show Copy", "显示副本")) { NSWorkspace.shared.activateFileViewerSelecting([converted]) }.buttonStyle(.link)
            }
            if let exported = model.lastExportedSubtitleURL {
                Button(L10n.text("Show Subtitles", "显示字幕文件")) { NSWorkspace.shared.activateFileViewerSelecting([exported]) }.buttonStyle(.link)
            }
            Spacer()
            Text(L10n.text("MAC NATIVE  /  0.5.3", "原生 MAC  /  0.5.3")).tracking(1.2).foregroundStyle(Palette.muted.opacity(0.7))
        }.font(.system(size: 10)).foregroundStyle(Palette.muted)
            .padding(.horizontal, 22).padding(.vertical, 10)
            .background(Palette.background)
    }
}

/// Original mark: a play signal connected to four neural nodes.
private struct AxonTubeMark: View {
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * unit, y: y * unit)
            }
            let plate = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: unit * 0.25)
            context.fill(plate, with: .linearGradient(
                Gradient(colors: [Palette.mint.opacity(0.18), Palette.mint.opacity(0.04)]),
                startPoint: .zero, endPoint: point(1, 1)))
            context.stroke(plate, with: .color(Palette.mint.opacity(0.25)), lineWidth: unit * 0.018)

            let nodes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.22, 0.24, 0.41, 0.34),
                (0.19, 0.73, 0.41, 0.63),
                (0.79, 0.23, 0.61, 0.43),
                (0.81, 0.76, 0.63, 0.55)
            ]
            for (x, y, targetX, targetY) in nodes {
                var connection = Path()
                connection.move(to: point(x, y))
                connection.addLine(to: point(targetX, targetY))
                context.stroke(connection, with: .color(Palette.mint.opacity(0.6)),
                               style: StrokeStyle(lineWidth: unit * 0.024, lineCap: .round))
                let node = Path(ellipseIn: CGRect(x: (x - 0.037) * unit, y: (y - 0.037) * unit,
                                                width: unit * 0.074, height: unit * 0.074))
                context.fill(node, with: .color(Palette.mint))
            }
            var signal = Path()
            signal.move(to: point(0.39, 0.29))
            signal.addLine(to: point(0.72, 0.50))
            signal.addLine(to: point(0.39, 0.71))
            signal.closeSubpath()
            context.fill(signal, with: .color(Palette.mint))
            context.stroke(signal, with: .color(Palette.mint),
                           style: StrokeStyle(lineWidth: unit * 0.032, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Keep the requested font size even for long captions. Only the caption area
/// scrolls when its natural height exceeds the available video layout.
private struct CaptionPanel: View {
    @AppStorage(L10n.preferenceKey) private var interfaceLanguage = AppLanguage.english.rawValue
    let first: String
    let second: String
    let fontSize: Double
    let maximumHeight: CGFloat
    var placeholder = ""
    var overVideo = false
    @State private var contentHeight: CGFloat = 0

    private var empty: Bool { first.isEmpty && second.isEmpty }

    var body: some View {
        if empty && overVideo {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 7) {
                        Color.clear.frame(height: 0).id("caption-top")
                        if empty {
                            Text(placeholder).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        } else {
                            if !first.isEmpty { caption(first, size: fontSize, color: .white, weight: .medium) }
                            if !second.isEmpty { caption(second, size: max(14, fontSize - 4), color: Palette.gold, weight: .regular) }
                        }
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: CaptionHeightKey.self, value: geometry.size.height)
                    })
                }
                .frame(height: min(maximumHeight, max(overVideo ? 0 : 56, contentHeight)))
                .overlay(alignment: .bottomTrailing) {
                    if contentHeight > maximumHeight + 1 {
                        Text(L10n.text("Scroll to read the full sentence", "上下滚动查看整句")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.black.opacity(0.75), in: Capsule()).padding(4)
                            .allowsHitTesting(false)
                    }
                }
                .onPreferenceChange(CaptionHeightKey.self) { contentHeight = $0 }
                .onChange(of: first) { _, _ in proxy.scrollTo("caption-top", anchor: .top) }
                .onChange(of: second) { _, _ in proxy.scrollTo("caption-top", anchor: .top) }
                .onChange(of: fontSize) { _, _ in proxy.scrollTo("caption-top", anchor: .top) }
            }
            .environment(\.locale, Locale(identifier: interfaceLanguage))
        }
    }

    private func caption(_ text: String, size: Double, color: Color, weight: Font.Weight) -> some View {
        Text(text).font(.system(size: size, weight: weight)).foregroundStyle(color)
            .lineSpacing(3).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .padding(.horizontal, overVideo ? 10 : 0).padding(.vertical, overVideo ? 4 : 0)
            .background(overVideo ? .black.opacity(0.7) : .clear, in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct CaptionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct YouTubeMessageHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var compact = false
    var isSelected = false
    var isBusy = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: compact ? 11 : 12, weight: .medium))
            .foregroundStyle(isBusy ? Palette.gold : !isEnabled ? Palette.muted.opacity(0.5) : isSelected ? Palette.mint : .white.opacity(0.88))
            .padding(.horizontal, compact ? 10 : 13).padding(.vertical, compact ? 8 : 10)
            .background(isBusy ? Palette.gold.opacity(0.08) : !isEnabled ? .white.opacity(0.025) : isSelected ? Palette.mint.opacity(configuration.isPressed ? 0.23 : 0.14) : .white.opacity(configuration.isPressed ? 0.15 : 0.065), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isBusy ? Palette.gold.opacity(0.4) : !isEnabled ? .white.opacity(0.07) : isSelected ? Palette.mint.opacity(0.75) : .white.opacity(configuration.isPressed ? 0.4 : 0.22)))
            .scaleEffect(isEnabled && configuration.isPressed ? 0.97 : 1)
    }
}

private struct MintButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isEnabled ? Palette.background : Palette.muted.opacity(0.5))
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background(isEnabled ? Palette.mint.opacity(configuration.isPressed ? 0.8 : 1) : .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isEnabled ? Palette.mint : .white.opacity(0.07)))
            .scaleEffect(isEnabled && configuration.isPressed ? 0.97 : 1)
    }
}

private struct TransportButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(!isEnabled ? Palette.muted.opacity(0.45) : prominent ? Palette.background : .white.opacity(0.88))
            .frame(width: prominent ? 43 : 35, height: prominent ? 43 : 35)
            .background(!isEnabled ? .white.opacity(0.025) : prominent ? Palette.mint.opacity(configuration.isPressed ? 0.8 : 1) : .white.opacity(configuration.isPressed ? 0.15 : 0.065), in: Circle())
            .overlay(Circle().strokeBorder(!isEnabled ? .white.opacity(0.07) : prominent ? Palette.mint : .white.opacity(0.22)))
            .scaleEffect(isEnabled && configuration.isPressed ? 0.94 : 1)
    }
}

private final class PlayerLayerView: NSView {
    override func makeBackingLayer() -> CALayer { AVPlayerLayer() }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override var isFlipped: Bool { false }
}

private struct VideoSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.wantsLayer = true
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }
    func updateNSView(_ view: PlayerLayerView, context: Context) { view.playerLayer.player = player }
}
