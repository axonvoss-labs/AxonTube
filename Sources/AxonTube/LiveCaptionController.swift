import AppKit
import AVFoundation
import Combine
import PlayerCore
import Speech
import Translation

@MainActor
final class LiveCaptionController: ObservableObject {
    @Published var enabled = false
    @Published var running = false
    @Published var busy = false
    @Published var status = LocalizedText("Live transcription is off.", "实时听写尚未开启")
    @Published var modelReady = false
    @Published var modelMessage = LocalizedText("Check the speech model for the selected language.", "检查所选语言的语音模型")
    @Published var modelProgress: Double?
    @Published var downloadingModel = false
    @Published var chineseEnabled = true
    @Published var translationReady = false
    @Published var translationStatus = LocalizedText("Translation requires on-device language packs.", "翻译需要本机语言包")
    @Published private(set) var sourceLocaleIdentifier = UserDefaults.standard.string(forKey: SpeechLanguageSettings.sourcePreferenceKey) ?? SpeechLanguageSettings.defaultSourceIdentifier
    @Published private(set) var targetLanguageIdentifier = UserDefaults.standard.string(forKey: SpeechLanguageSettings.targetPreferenceKey) ?? SpeechLanguageSettings.defaultTargetIdentifier
    @Published private(set) var speechLanguages: [SpeechLanguageOption] = []
    @Published private(set) var translationLanguages: [SpeechLanguageOption] = []
    @Published private(set) var checkingLanguages = false
    @Published private(set) var speechModelCanPrepare = false
    @Published private(set) var translationSupported = false
    @Published private(set) var preparingTranslation = false
    @Published private(set) var languageRevision = UUID()
    @Published var latestEnglish = ""
    @Published var latestChinese = ""
    @Published var transcript = LiveTranscript()
    @Published private(set) var track = SubtitleTrack(cues: [])
    @Published var showSettings = false
    var clock: () -> (time: Double, playing: Bool, speed: Double, ended: Bool) = { (0, false, 1, false) }
    private var engineObject: AnyObject?
    private var feedObject: AnyObject?
    private var captureObject: AnyObject?
    private var translationObject: AnyObject?
    private var work: Task<Void, Never>?
    private var stopWork: Task<Void, Never>?
    private var translationWork: Task<Void, Never>?
    private var languageCheckWork: Task<Void, Never>?
    private var modelInstallWork: Task<Void, Never>?
    private var translationPreparationObject: AnyObject?
    private var modelCheckToken = UUID()
    private var resolvedInitialLanguages = false
    private var translationEpoch = UUID()
    private var token = UUID()
    private var sourceURL: URL?
    private var youtubeSource = false
    private var lastTextAt = Date.distantPast
    private var captureTime = 0.0
    private var captureBase = 0.0
    private var captureRate = 1.0
    private var captureHasBase = false
    private var translationFailures: Set<Int> = []
    private var wantsLive = false

    var currentText: String { !clock().playing || Date().timeIntervalSince(lastTextAt) < 7 ? latestEnglish : "" }
    var currentTranslation: String { chineseEnabled && (!clock().playing || Date().timeIntervalSince(lastTextAt) < 7) ? latestChinese : "" }
    var sourceLanguageName: String { SpeechLanguageOption(identifier: sourceLocaleIdentifier).name }
    var targetLanguageName: String { SpeechLanguageOption(identifier: targetLanguageIdentifier).name }
    var translationSourceIdentifier: String? {
        SpeechLanguageSettings.languageMatch(sourceLocaleIdentifier, in: translationLanguages)?.identifier
    }
    var canPrepareTranslation: Bool { translationSupported && !checkingLanguages && !preparingTranslation }

    private var translationPairName: LocalizedText {
        SpeechLanguageOption(identifier: sourceLocaleIdentifier).bilingualName + " → "
            + SpeechLanguageOption(identifier: targetLanguageIdentifier).bilingualName
    }

    func configureSource(url: URL?, youtube: Bool) {
        stop()
        enabled = false
        transcript = LiveTranscript()
        track = SubtitleTrack(cues: [])
        latestEnglish = ""; latestChinese = ""
        sourceURL = url; youtubeSource = youtube
        translationFailures = []
    }

    func setSourceLocaleIdentifier(_ identifier: String) {
        guard identifier != sourceLocaleIdentifier,
              SpeechLanguageSettings.exactMatch(identifier, in: speechLanguages) != nil else { return }
        changeLanguages(source: identifier, target: targetLanguageIdentifier)
    }

    func setTargetLanguageIdentifier(_ identifier: String) {
        guard identifier != targetLanguageIdentifier,
              SpeechLanguageSettings.exactMatch(identifier, in: translationLanguages) != nil else { return }
        changeLanguages(source: sourceLocaleIdentifier, target: identifier)
    }

    private func changeLanguages(source: String, target: String) {
        stop()
        languageRevision = UUID()
        languageCheckWork?.cancel()
        modelInstallWork?.cancel(); modelInstallWork = nil
        downloadingModel = false; modelProgress = nil
        if #available(macOS 26.0, *) {
            (translationPreparationObject as? TranslationSession)?.cancel()
            translationPreparationObject = nil
        }
        preparingTranslation = false
        sourceLocaleIdentifier = source; targetLanguageIdentifier = target
        UserDefaults.standard.set(source, forKey: SpeechLanguageSettings.sourcePreferenceKey)
        UserDefaults.standard.set(target, forKey: SpeechLanguageSettings.targetPreferenceKey)
        // A language choice starts a new transcript; old text cannot acquire a new language label.
        transcript = LiveTranscript(); track = SubtitleTrack(cues: [])
        latestEnglish = ""; latestChinese = ""; translationFailures = []
        status = LocalizedText("Languages changed · Live captions cleared. Start a new transcription when ready.", "语言已更改 · 实时字幕已清空，请在准备好后重新开始听写。")
        checkModels()
    }

    /// Read-only discovery. Model preparation is only triggered by the settings buttons.
    func checkModels() {
        guard #available(macOS 26.0, *) else {
            modelMessage = LocalizedText("Live transcription requires an Apple Silicon Mac with macOS 26 or later.", "实时听写需要 Apple Silicon Mac 和 macOS 26 或更新版本。")
            return
        }
        languageCheckWork?.cancel()
        let check = UUID(); modelCheckToken = check
        let revision = languageRevision
        checkingLanguages = true
        modelReady = false; speechModelCanPrepare = false
        translationReady = false; translationSupported = false
        modelMessage = LocalizedText("Checking supported languages…", "正在检查支持的语言…")
        translationStatus = LocalizedText("Checking the selected translation pair…", "正在检查所选翻译语言组合…")
        languageCheckWork = Task { [weak self] in
            guard let self else { return }
            defer { if modelCheckToken == check { checkingLanguages = false; languageCheckWork = nil } }
            let speech = await LiveSpeechEngine.supportedLanguageOptions()
            let availability = LanguageAvailability()
            let translations = await availability.supportedLanguages
            guard languageRevision == revision, modelCheckToken == check, !Task.isCancelled else { return }
            speechLanguages = speech
            translationLanguages = SpeechLanguageSettings.options(identifiers: translations.map(\.minimalIdentifier))
            if !resolvedInitialLanguages {
                if let saved = SpeechLanguageSettings.exactMatch(sourceLocaleIdentifier, in: speechLanguages) {
                    sourceLocaleIdentifier = saved.identifier
                } else if UserDefaults.standard.string(forKey: SpeechLanguageSettings.sourcePreferenceKey) == nil,
                          let preferred = SpeechLanguageSettings.defaultSpeech(in: speechLanguages) {
                    sourceLocaleIdentifier = preferred.identifier
                }
                if let saved = SpeechLanguageSettings.languageMatch(targetLanguageIdentifier, in: translationLanguages) {
                    targetLanguageIdentifier = saved.identifier
                }
                resolvedInitialLanguages = true
            }
            let source = sourceLocaleIdentifier
            let target = targetLanguageIdentifier
            let info = await LiveSpeechEngine.checkModel(localeIdentifier: source)
            guard languageRevision == revision, modelCheckToken == check, !Task.isCancelled else { return }
            modelReady = info.status == .installed
            speechModelCanPrepare = info.status == .notInstalled || info.status == .downloading
            modelMessage = info.message
            guard let translationSource = translationSourceIdentifier,
                  SpeechLanguageSettings.exactMatch(target, in: translationLanguages) != nil else {
                translationStatus = LocalizedText("The selected language is unavailable in Apple's translation language list on this Mac.", "所选语言不在此 Mac 的 Apple 翻译支持列表中。")
                return
            }
            let state = await availability.status(from: Locale.Language(identifier: translationSource), to: Locale.Language(identifier: target))
            guard languageRevision == revision, modelCheckToken == check, !Task.isCancelled else { return }
            updateTranslationAvailability(state)
            if translationReady && chineseEnabled { prepareInstalledTranslation() }
        }
    }

    func installModel() {
        guard #available(macOS 26.0, *), !busy, !downloadingModel, speechModelCanPrepare, !checkingLanguages else { return }
        let revision = languageRevision
        let source = sourceLocaleIdentifier
        downloadingModel = true; modelMessage = LocalizedText("Preparing the selected speech model…", "正在准备所选语音模型…")
        modelInstallWork = Task { [weak self] in
            guard let self else { return }
            defer {
                if languageRevision == revision { downloadingModel = false; modelProgress = nil; modelInstallWork = nil }
            }
            do {
                let installer = LiveSpeechEngine(localeIdentifier: source)
                try await installer.installModel { [weak self] progress in
                    guard self?.languageRevision == revision else { return }
                    self?.modelProgress = progress
                }
                guard languageRevision == revision, !Task.isCancelled else { return }
                checkModels()
            } catch {
                guard languageRevision == revision, !Task.isCancelled else { return }
                modelMessage = LocalizedText("Model preparation failed: ", "模型准备失败：") + LocalizedText(error: error)
            }
        }
    }

    @available(macOS 26.0, *)
    private func updateTranslationAvailability(_ state: LanguageAvailability.Status) {
        translationReady = state == .installed
        translationSupported = state != .unsupported
        switch state {
        case .installed:
            translationStatus = translationPairName + LocalizedText(" · On-device translation is ready.", " · 本机翻译已就绪")
        case .supported:
            translationStatus = translationPairName + LocalizedText(" · Prepare the translation packs before first use.", " · 首次使用前请准备翻译语言包")
        case .unsupported:
            translationStatus = LocalizedText("This language combination is not supported by Apple's on-device translation.", "Apple 本机翻译不支持此语言组合。")
        @unknown default:
            translationSupported = false
            translationStatus = LocalizedText("Translation availability could not be determined.", "暂时无法确认翻译可用性。")
        }
    }

    @available(macOS 26.0, *)
    func prepareInstalledTranslation() {
        guard translationReady, chineseEnabled, let source = translationSourceIdentifier else { return }
        translationEpoch = UUID()
        translationWork?.cancel(); translationWork = nil
        (translationObject as? TranslationSession)?.cancel()
        translationFailures = []
        // Match LanguageAvailability's default strategy when selecting installed assets.
        translationObject = TranslationSession(installedSource: Locale.Language(identifier: source), target: Locale.Language(identifier: targetLanguageIdentifier))
        translatePending()
    }

    func setChineseEnabled(_ value: Bool) {
        chineseEnabled = value
        translationEpoch = UUID()
        translationWork?.cancel(); translationWork = nil
        if #available(macOS 26.0, *) {
            (translationObject as? TranslationSession)?.cancel()
            translationObject = nil
            if value && translationReady { prepareInstalledTranslation() }
        }
        latestChinese = value ? transcript.captions.last(where: { $0.text == latestEnglish })?.translation ?? "" : ""
    }

    @available(macOS 26.0, *)
    func prepareTranslation(using session: TranslationSession, revision: UUID) async {
        guard revision == languageRevision, translationSupported,
              let source = translationSourceIdentifier,
              session.sourceLanguage?.minimalIdentifier == Locale.Language(identifier: source).minimalIdentifier,
              session.targetLanguage?.minimalIdentifier == Locale.Language(identifier: targetLanguageIdentifier).minimalIdentifier else { return }
        let target = targetLanguageIdentifier
        preparingTranslation = true
        translationPreparationObject = session
        defer {
            if revision == languageRevision {
                preparingTranslation = false
                translationPreparationObject = nil
            }
        }
        translationStatus = LocalizedText("Preparing offline translation packs…", "正在准备离线翻译包…")
        do {
            try await session.prepareTranslation()
            guard revision == languageRevision, !Task.isCancelled else { return }
            let state = await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
            guard revision == languageRevision, !Task.isCancelled else { return }
            updateTranslationAvailability(state)
            if translationReady && chineseEnabled { prepareInstalledTranslation() }
        } catch {
            guard revision == languageRevision, !Task.isCancelled else { return }
            translationStatus = LocalizedText("Translation is not ready: ", "翻译尚未就绪：") + LocalizedText(error: error)
        }
    }

    func start() {
        guard #available(macOS 26.0, *) else { status = LocalizedText("Live transcription requires macOS 26 or later.", "实时听写需要 macOS 26 或更新版本"); return }
        guard sourceURL != nil || youtubeSource else { status = LocalizedText("Open a video first.", "请先打开视频"); return }
        guard modelReady, !checkingLanguages else { status = modelMessage; return }
        enabled = true
        wantsLive = true
        restart(keepingCapture: false)
    }

    func didSeek() {
        guard wantsLive, #available(macOS 26.0, *) else { return }
        restart(keepingCapture: true)
    }

    @available(macOS 26.0, *)
    private func restart(keepingCapture: Bool) {
        let session = UUID(); token = session
        let source = sourceLocaleIdentifier
        work?.cancel(); translationWork?.cancel(); translationWork = nil
        let oldEngine = engineObject as? LiveSpeechEngine
        let oldFeed = feedObject as? LocalAudioFeed
        let pendingStop = stopWork
        (captureObject as? PlayerAudioCapture)?.discardPendingAudio()
        engineObject = nil; feedObject = nil
        running = false; busy = true
        latestEnglish = ""; latestChinese = ""
        status = LocalizedText("Starting on-device live transcription…", "正在连接本地实时听写…")
        work = Task { [weak self] in
            guard let self else { return }
            oldFeed?.cancel()
            await oldEngine?.cancel()
            await pendingStop?.value
            guard token == session, !Task.isCancelled else { return }
            do {
                let engine = LiveSpeechEngine(localeIdentifier: source)
                engineObject = engine
                let format = try await engine.start(onResult: { [weak self] result in
                    guard let self, self.token == session else { return }
                    self.receive(result)
                }, onError: { [weak self] error in
                    guard let self, self.token == session else { return }
                    self.fail(LocalizedText(error: error))
                })
                guard token == session, !Task.isCancelled else { await engine.cancel(); return }
                captureTime = 0; captureHasBase = false; captureRate = clock().speed
                if youtubeSource {
                    if !keepingCapture || (captureObject as? PlayerAudioCapture)?.isCapturing != true {
                        if let old = captureObject as? PlayerAudioCapture { await old.stop() }
                        guard token == session, !Task.isCancelled else { return }
                        let capture = PlayerAudioCapture()
                        captureObject = capture
                        status = LocalizedText("Select AxonTube in the system picker to use its video audio.", "请在系统选择器中选择 AxonTube，以接入视频声音")
                        // Model preparation completes before the user chooses the audio source.
                        try await capture.start(onBuffer: { [weak self] buffer in
                            try await self?.captureBuffer(buffer)
                        }, onError: { [weak self, weak capture] message in
                            guard let self, let capture, self.captureObject === capture else { return }
                            self.fail(message)
                        })
                    }
                } else if let url = sourceURL {
                    let feed = LocalAudioFeed(); feedObject = feed
                    try await feed.start(url: url, startTime: clock().time, targetFormat: format,
                        clock: { [weak self] in
                            let value = self?.clock() ?? (time: 0, playing: false, speed: 1, ended: false)
                            return LocalAudioClock(time: value.time, isPlaying: value.playing, hasEnded: value.ended)
                        }, onBuffer: { [weak self, weak engine] buffer, time in
                            guard self?.token == session else { throw CancellationError() }
                            try await engine?.append(buffer, mediaTime: time)
                        }, onFinish: { [weak self, weak engine] in
                            guard self?.token == session else { return }
                            Task { @MainActor in
                                do { try await engine?.finish() }
                                catch { if self?.token == session { self?.status = LocalizedText(error: error) } }
                                guard self?.token == session else { return }
                                self?.running = false; self?.status = LocalizedText("Transcription finished · Click a caption to listen again.", "本段听写完成 · 可点击字幕复听")
                            }
                        }, onError: { [weak self] error in
                            guard self?.token == session else { return }; self?.fail(LocalizedText(error: error))
                        })
                }
                guard token == session, !Task.isCancelled else { return }
                running = true; busy = false
                status = youtubeSource
                    ? LocalizedText("Live transcription · Captions appear when the video plays.", "正在实时听写 · 播放视频后出现文字")
                    : LocalizedText("Live transcription · Processing on this Mac.", "正在实时听写 · 本机处理")
                if translationReady { prepareInstalledTranslation() }
            } catch is CancellationError {
                if token == session { fail(LocalizedText("Live transcription was cancelled.", "已取消实时听写")) }
            } catch {
                if token == session { fail(LocalizedText("Transcription could not start: ", "无法启动听写：") + LocalizedText(error: error)); checkModels() }
            }
        }
    }

    @available(macOS 26.0, *)
    private func captureBuffer(_ buffer: AVAudioPCMBuffer) async throws {
        guard running, let engine = engineObject as? LiveSpeechEngine else { return }
        let session = token
        let now = clock()
        guard now.playing else { return }
        if !captureHasBase { captureBase = max(0, now.time - 0.1); captureHasBase = true }
        let time = captureTime
        captureTime += Double(buffer.frameLength) / buffer.format.sampleRate
        do { try await engine.append(buffer, mediaTime: CMTime(seconds: time, preferredTimescale: 16000)) }
        catch { if token == session { throw error } }
    }

    @available(macOS 26.0, *)
    private func receive(_ result: LiveSpeechResult) {
        let scale = youtubeSource ? captureRate : 1
        let base = youtubeSource ? captureBase : 0
        let start = base + result.range.start.seconds * scale
        let end = base + result.range.end.seconds * scale
        let final = base + result.finalizedThrough.seconds * scale
        transcript.update(text: result.text, start: start, end: end,
                          isFinal: result.isFinal, finalizedThrough: final)
        track = transcript.track
        let cleanText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        latestEnglish = cleanText
        latestChinese = transcript.captions.last(where: { $0.text == cleanText })?.translation ?? ""
        lastTextAt = Date()
        status = result.isFinal
            ? LocalizedText("Live transcription · Sentence finalized.", "实时听写 · 句子已确认")
            : LocalizedText("Transcribing · Draft text may change.", "正在听写 · 文字会继续修正")
        translatePending()
    }

    @available(macOS 26.0, *)
    private func translatePending() {
        guard chineseEnabled, translationReady, translationWork == nil,
              let translator = translationObject as? TranslationSession else { return }
        let session = token
        let epoch = translationEpoch
        translationWork = Task { [weak self] in
            guard let self else { return }
            defer { if token == session && translationEpoch == epoch { translationWork = nil } }
            while token == session, translationEpoch == epoch, chineseEnabled, !Task.isCancelled,
                  let caption = transcript.captions.first(where: { $0.isFinal && $0.translation == nil && !self.translationFailures.contains($0.id) }) {
                do {
                    let translated = try await translator.translate(caption.text)
                    guard token == session, translationEpoch == epoch, chineseEnabled, !Task.isCancelled else { return }
                    transcript.translate(id: caption.id, source: caption.text, text: translated.targetText)
                    if latestEnglish == caption.text { latestChinese = translated.targetText }
                    translationStatus = translationPairName + LocalizedText(" · On-device translation.", " · 本机翻译")
                } catch {
                    guard token == session, translationEpoch == epoch, !Task.isCancelled else { return }
                    translationFailures.insert(caption.id)
                    let detail = error as NSError
                    translationStatus = LocalizedText("This sentence could not be translated: ", "本句翻译失败：")
                        + LocalizedText(error: error)
                        + LocalizedText(" (\(detail.domain) \(detail.code))", "（\(detail.domain) \(detail.code)）")
                }
            }
        }
    }

    private func fail(_ message: LocalizedText) { stop(); status = message }

    func finishYouTube() {
        guard youtubeSource, running, #available(macOS 26.0, *), let engine = engineObject as? LiveSpeechEngine else { return }
        running = false
        let session = token
        let capture = captureObject as? PlayerAudioCapture
        captureObject = nil
        work = Task {
            await capture?.stop()
            do {
                try await engine.finish()
                guard token == session else { return }
                status = LocalizedText("Transcription finished · Select the app audio again before replaying.", "本段听写完成 · 重新播放时请重新选择应用音频")
            } catch { if token == session { fail(LocalizedText(error: error)) } }
        }
    }

    func stop() {
        wantsLive = false
        token = UUID()
        work?.cancel(); work = nil
        translationEpoch = UUID()
        translationWork?.cancel(); translationWork = nil
        running = false; busy = false
        status = LocalizedText("Live transcription stopped · Generated captions remain in the list.", "实时听写已停止 · 已生成字幕保留在列表中")
        if #available(macOS 26.0, *) {
            (translationObject as? TranslationSession)?.cancel()
            translationObject = nil
            let engine = engineObject as? LiveSpeechEngine
            let feed = feedObject as? LocalAudioFeed
            let capture = captureObject as? PlayerAudioCapture
            engineObject = nil; feedObject = nil; captureObject = nil
            feed?.cancel()
            let previousStop = stopWork
            stopWork = Task {
                await previousStop?.value
                await capture?.stop()
                await engine?.cancel()
            }
        }
    }
}
