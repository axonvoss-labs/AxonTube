import SwiftUI
import Translation
import PlayerCore

@available(macOS 26.0, *)
struct LiveCaptionSettings: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var live: LiveCaptionController
    @AppStorage(L10n.preferenceKey) private var interfaceLanguage = AppLanguage.english.rawValue
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var translationPreparationRevision: UUID?

    var body: some View {
        let preparationRevision = translationPreparationRevision
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "waveform.badge.mic").foregroundStyle(.mint).font(.title2)
                Text(L10n.text("Live Captions & Translation", "实时听写与翻译")).font(.title2.bold())
                Spacer()
                Button(L10n.text("Done", "完成")) { live.showSettings = false }
            }
            Text(L10n.text("Transcribe the selected spoken language as the video plays. Translation follows finalized sentences. Both run on this Mac without API tokens.", "边播放，边听写所选语言的声音，句子确认后生成翻译。识别和翻译均在本机运行，不使用 API token。"))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                Picker(L10n.text("Speech Language (First Caption)", "听写语言（第一字幕）"), selection: Binding(get: { live.sourceLocaleIdentifier }, set: live.setSourceLocaleIdentifier)) {
                    if !live.speechLanguages.contains(where: { $0.identifier == live.sourceLocaleIdentifier }) {
                        Text(live.sourceLanguageName + " · " + L10n.text("Unavailable", "不可用")).tag(live.sourceLocaleIdentifier).disabled(true)
                    }
                    ForEach(live.speechLanguages.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { language in
                        Text(language.name).tag(language.identifier)
                    }
                }.disabled(live.checkingLanguages || live.speechLanguages.isEmpty)
                Picker(L10n.text("Translation Language (Second Caption)", "翻译语言（第二字幕）"), selection: Binding(get: { live.targetLanguageIdentifier }, set: live.setTargetLanguageIdentifier)) {
                    if !live.translationLanguages.contains(where: { $0.identifier == live.targetLanguageIdentifier }) {
                        Text(live.targetLanguageName + " · " + L10n.text("Unavailable", "不可用")).tag(live.targetLanguageIdentifier).disabled(true)
                    }
                    ForEach(live.translationLanguages.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { language in
                        Text(language.name).tag(language.identifier)
                    }
                }.disabled(live.checkingLanguages || live.translationLanguages.isEmpty)
                HStack {
                    if live.checkingLanguages {
                        ProgressView().controlSize(.small)
                        Text(L10n.text("Checking supported languages…", "正在检查支持的语言…")).font(.caption)
                    }
                    Spacer()
                    Button(L10n.text("Refresh Languages", "刷新语言")) { live.checkModels() }
                        .disabled(live.checkingLanguages || live.downloadingModel || live.preparingTranslation)
                }
                Text(L10n.text("Changing either language stops transcription and clears the current live captions. YouTube subtitle language choices are separate.", "更改任一语言会停止听写并清空当前实时字幕。YouTube 字幕的语言选择独立保存。"))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            GroupBox(L10n.text("Speech Model", "语音模型")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(live.modelMessage.text).font(.callout)
                    if let progress = live.modelProgress { ProgressView(value: progress) }
                    if !live.modelReady {
                        Button(live.downloadingModel ? L10n.text("Preparing…", "准备中…") : L10n.text("Download / Prepare Speech Model", "下载 / 准备语音模型")) { live.installModel() }
                            .disabled(live.downloadingModel || live.checkingLanguages || !live.speechModelCanPrepare || live.busy)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(L10n.text("Translate Second Caption", "生成第二字幕翻译"), isOn: Binding(get: { live.chineseEnabled }, set: live.setChineseEnabled))
                    Text(live.translationStatus.text).font(.callout).foregroundStyle(.secondary)
                    if !live.translationReady {
                        Button(L10n.text("Prepare Offline Translation…", "准备离线翻译包…")) {
                            guard let source = live.translationSourceIdentifier else { return }
                            translationPreparationRevision = live.languageRevision
                            translationConfiguration = .init(source: .init(identifier: source), target: .init(identifier: live.targetLanguageIdentifier))
                        }.disabled(!live.canPrepareTranslation)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            if model.youtube != nil {
                Text(L10n.text("For YouTube, select AxonTube in the macOS picker after starting. Only this app’s playback audio is sent to local speech recognition. The microphone and videos playing in your browser are not captured.", "YouTube：开始后在 macOS 系统选择器中选择 AxonTube。仅将此应用播放的声音交给本地识别，不开启麦克风。浏览器中播放的视频不在采集范围。"))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text(live.status.text).font(.callout).foregroundStyle(.mint)
            HStack {
                Button(L10n.text("Use Imported Subtitles", "使用导入字幕")) { live.stop(); live.enabled = false; live.showSettings = false }
                Spacer()
                if live.running || live.busy {
                    Button(L10n.text("Stop Captions", "停止听写")) { live.stop() }
                } else {
                    Button(L10n.text("Start Live Captions", "开始实时听写")) { live.start(); live.showSettings = false }
                        .buttonStyle(.borderedProminent).disabled(!model.hasMedia || !live.modelReady)
                }
            }
            Text(L10n.text("An internet connection is needed to prepare models the first time. After downloading, local-video recognition and translation work offline. Live captions may be delayed or contain recognition errors.", "首次准备模型需要联网；下载完成后，本地视频的听写和翻译可离线使用。实时字幕存在处理延迟，也可能识别错误。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("The language menus show only languages reported by Apple on this Mac. Some speech and translation combinations are unavailable.", "语言菜单仅显示此 Mac 上 Apple 报告支持的语言，部分听写与翻译语言组合不可用。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        }
        .frame(width: 640, height: 740)
        .environment(\.locale, Locale(identifier: interfaceLanguage))
        .task { live.checkModels() }
        .onChange(of: live.languageRevision) { _, _ in
            translationConfiguration = nil
            translationPreparationRevision = nil
        }
        .translationTask(translationConfiguration) { session in
            guard let preparationRevision else { return }
            await live.prepareTranslation(using: session, revision: preparationRevision)
            if translationPreparationRevision == preparationRevision {
                translationConfiguration = nil
                translationPreparationRevision = nil
            }
        }
    }
}
