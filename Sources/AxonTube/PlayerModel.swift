import AppKit
import AVFoundation
import Combine
import Foundation
import PlayerCore
import UniformTypeIdentifiers

struct SubtitleSlot: Sendable {
    var name = ""
    var track = SubtitleTrack(cues: [])
    var offset = 0.0
    var isVisible = true
    var sourceURL: URL?
    var websiteTrack: YouTubeCaptionTrack?

    var displayName: String {
        websiteTrack.map { "YouTube · \($0.displayName)" } ?? name
    }
}

@MainActor
final class PlayerModel: ObservableObject {
    let player = AVPlayer()
    let live = LiveCaptionController()
    let youtubeCaptions: YouTubeCaptionFetcher
    let videoSaver = VideoSaveController()
    private var liveObservation: AnyCancellable?
    private var captionObservation: AnyCancellable?
    private var saveObservation: AnyCancellable?
    private var youtubeSubtitleLink: YouTubeLink?
    private var captionRequestGeneration = UUID()
    private var captionSaveGeneration = UUID()
    private var lastYouTubeCaptionResult: YouTubeCaptionResult?
    private var lastYouTubeCaptionRevision = UUID()
    private var captionSelectionTask: Task<Void, Never>?
    private var lastYouTubeTick: (time: Double, wall: Date, rate: Double)?
    private var localSeeking = false
    private var seekSession = UUID()
    private var youtubeAudioPlaying = false
    private var pendingYouTubeSeek: (target: Double, requested: Date)?
    @Published var mediaURL: URL?
    @Published var slots = [SubtitleSlot(), SubtitleSlot()] {
        didSet {
            let offsetsChanged = zip(oldValue, slots).contains { pair in pair.0.offset != pair.1.offset }
            let tracksChanged = zip(oldValue, slots).contains { pair in pair.0.track.cues != pair.1.track.cues }
            if offsetsChanged || tracksChanged {
                if offsetsChanged || oldValue[0].track.cues != slots[0].track.cues {
                    sentenceTracks = nil
                } else if let sentenceTracks {
                    // Translation replacement/removal must not leave the previous
                    // text visible while rebuilding. Keep stable English groups.
                    self.sentenceTracks = [sentenceTracks[0], SubtitleTrack(cues: [])]
                    sentenceTextByID[1] = [:]
                }
                if offsetsChanged, !live.enabled { loopEnabled = false; loopCueID = nil }
                rebuildSentenceTracks()
            }
        }
    }
    @Published var currentTime = 0.0
    @Published var duration = 0.0
    @Published var isPlaying = false
    @Published var localPlaybackEnded = false
    @Published var isLoading = false
    @Published var speed: Double = 1.0
    @Published var volume: Double = 0.8
    @Published var loopEnabled = false
    @Published var loopCueID: Int?
    private var loopCueSnapshot: SubtitleCue?
    private var loopSnapshotOffset = 0.0
    @Published var search = ""
    @Published var followCurrent = true
    @Published var subtitleSize = 24.0 {
        didSet { UserDefaults.standard.set(subtitleSize, forKey: "subtitle.fontSize") }
    }
    @Published var subtitleListSize = 14.0 {
        didSet { UserDefaults.standard.set(subtitleListSize, forKey: "subtitle.listFontSize") }
    }
    @Published var sentenceMode = true {
        didSet {
            UserDefaults.standard.set(sentenceMode, forKey: "subtitle.groupSentences")
            loopEnabled = false; loopCueID = nil
            rebuildSentenceTracks()
        }
    }
    @Published private(set) var sentencesBuilding = false
    @Published private var sentenceTracks: [SubtitleTrack]?
    private var sentenceTextByID: [[Int: String]] = [[:], [:]]
    private var sentenceTask: Task<Void, Never>?
    private var sentenceWorker: Task<SubtitleSentenceBuilder.Result, Never>?
    private var sentenceGeneration = UUID()
    @Published var errorMessage: LocalizedText?
    @Published var notice = LocalizedText("Local media and subtitles stay on your Mac", "所有视频和字幕均在本机处理")
    @Published var conversionProgress: Double?
    @Published var isConverting = false
    @Published var lastConvertedURL: URL?
    @Published var selectedPanel = 0
    @Published var youtube: YouTubeController?
    @Published var youtubeReady = false
    @Published var youtubeMessage: LocalizedText?
    @Published var youtubeRates: [Double] = [1]
    @Published var showYouTubeSheet = false
    @Published var primaryCaptionLanguage = UserDefaults.standard.string(forKey: "captions.primaryLanguage") ?? "en" {
        didSet {
            guard primaryCaptionLanguage != oldValue else { return }
            UserDefaults.standard.set(primaryCaptionLanguage, forKey: "captions.primaryLanguage")
            captionLanguageChanged()
        }
    }
    @Published var secondaryCaptionLanguage = UserDefaults.standard.string(forKey: "captions.secondaryLanguage") ?? "zh-Hant" {
        didSet {
            guard secondaryCaptionLanguage != oldValue else { return }
            UserDefaults.standard.set(secondaryCaptionLanguage, forKey: "captions.secondaryLanguage")
            captionLanguageChanged()
        }
    }
    @Published private(set) var isExportingSubtitles = false
    @Published private(set) var lastExportedSubtitleURL: URL?
    private var timer: Any?
    private var statusObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var conversion: Process?
    private var mediaSession = UUID()
    private var conversionSession = UUID()
    private var lastLoopSeek = Date.distantPast

    var displayName: String { youtube.map { "YouTube · \($0.link.videoID)" } ?? mediaURL?.lastPathComponent ?? "AxonTube" }
    var hasMedia: Bool { mediaURL != nil || youtube != nil }
    var isReady: Bool { youtube != nil ? youtubeReady : player.currentItem?.status == .readyToPlay }
    var playbackRates: [Double] { youtube != nil ? youtubeRates : [0.5, 0.65, 0.75, 0.85, 1, 1.15, 1.25, 1.5, 1.75, 2] }
    var activeSlot: Int { slots[0].track.cues.isEmpty && !slots[1].track.cues.isEmpty ? 1 : selectedPanel }
    private var usingSentenceTracks: Bool { sentenceMode && sentenceTracks != nil && !live.enabled }
    private func displayTrack(slot: Int) -> SubtitleTrack { usingSentenceTracks ? sentenceTracks![slot] : slots[slot].track }
    private func displayOffset(slot: Int) -> Double { usingSentenceTracks ? 0 : slots[slot].offset }
    var canExportSubtitles: Bool {
        guard !isExportingSubtitles else { return false }
        if live.enabled { return live.transcript.captions.contains { $0.isFinal && !$0.text.isEmpty } }
        return !sentencesBuilding && slots.contains { !$0.track.cues.isEmpty }
    }
    var canSaveVideo: Bool {
        guard hasMedia, !videoSaver.isSaving else { return false }
        return youtube != nil || mediaURL?.isFileURL == true
    }
    var isPreparingYouTubeCaptions: Bool { youtubeCaptions.isFetching || captionSelectionTask != nil }
    var learningTrack: SubtitleTrack { live.enabled ? live.track : displayTrack(slot: activeSlot) }
    var learningOffset: Double { live.enabled ? 0 : displayOffset(slot: activeSlot) }
    var currentCueIndex: Int? { learningTrack.activeIndex(at: currentTime - learningOffset) }
    var currentCue: SubtitleCue? { currentCueIndex.map { learningTrack.cues[$0] } }
    private var loopCue: SubtitleCue? {
        if let loopCueSnapshot, loopCueSnapshot.id == loopCueID { return loopCueSnapshot }
        return learningTrack.cues.first(where: { $0.id == loopCueID })
    }
    private var loopOffset: Double {
        loopCueSnapshot?.id == loopCueID ? loopSnapshotOffset : learningOffset
    }
    var ffmpegURL: URL? {
        ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    init(youtubeCaptions: YouTubeCaptionFetcher? = nil) {
        self.youtubeCaptions = youtubeCaptions ?? YouTubeCaptionFetcher()
        let preferences = UserDefaults.standard
        if let size = preferences.object(forKey: "subtitle.fontSize") as? Double, size.isFinite {
            subtitleSize = min(48, max(16, size))
        }
        if let size = preferences.object(forKey: "subtitle.listFontSize") as? Double, size.isFinite {
            subtitleListSize = min(24, max(12, size))
        }
        sentenceMode = preferences.object(forKey: "subtitle.groupSentences") as? Bool ?? true
        live.clock = { [weak self] in
            guard let self else { return (0, false, 1, false) }
            let playing = self.youtube == nil ? self.isPlaying && !self.localSeeking : self.youtubeAudioPlaying
            return (self.currentTime, playing, self.speed, self.localPlaybackEnded)
        }
        liveObservation = live.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        captionObservation = self.youtubeCaptions.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        saveObservation = videoSaver.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        player.volume = Float(volume)
        timer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in self?.tick(time.seconds) }
        }
        playbackObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in
                guard let self, self.youtube == nil else { return }
                self.isPlaying = playing
            }
        }
        AppDelegate.openFiles = { [weak self] urls in self?.openURLs(urls) }
        AppDelegate.willExit = { [weak self] in self?.cancelConversion(); self?.sentenceTask?.cancel(); self?.sentenceWorker?.cancel(); self?.cancelCaptionWork(); self?.videoSaver.cancel(); self?.youtube?.invalidate(); self?.live.stop() }
        if !AppDelegate.pendingURLs.isEmpty {
            let urls = AppDelegate.pendingURLs
            AppDelegate.pendingURLs = []
            Task { @MainActor [weak self] in self?.openURLs(urls) }
        }
    }

    func tick(_ seconds: Double) {
        guard youtube == nil, !localSeeking, seconds.isFinite else { return }
        currentTime = max(0, seconds)
        if let item = player.currentItem, item.duration.seconds.isFinite { duration = max(0, item.duration.seconds) }
        checkLoop(at: seconds)
    }

    private func checkLoop(at seconds: Double) {
        guard loopEnabled, isPlaying, let cue = loopCue else { return }
        let start = max(0, cue.start + loopOffset)
        let end = min(duration > 0 ? duration : .greatestFiniteMagnitude, cue.end + loopOffset)
        if seconds >= end - 0.035, Date().timeIntervalSince(lastLoopSeek) > 0.15 {
            lastLoopSeek = Date()
            seek(to: start, preserveLoop: true)
            resumePlayback()
        }
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.prompt = L10n.text("Open", "打开")
        panel.title = L10n.text("Open Local Video or Audio", "打开本地视频或音频")
        panel.message = L10n.text("Open supported MP4, MOV, or M4V media. Other formats may need conversion.", "MP4、MOV、M4V 等格式可直接播放；其他格式可尝试兼容转换。")
        panel.allowedContentTypes = [.movie, .audio, .audiovisualContent, .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { openMedia(url) }
    }

    func chooseSubtitle(slot: Int) {
        let panel = NSOpenPanel()
        panel.prompt = L10n.text("Open", "打开")
        panel.title = slot == 0 ? L10n.text("Add Original Subtitles", "添加第一字幕（原文）") : L10n.text("Add Translated Subtitles", "添加第二字幕（译文）")
        panel.allowedContentTypes = ["srt", "vtt", "ass", "ssa"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { loadSubtitle(url, slot: slot) }
    }

    /// Capture both tracks before the save panel opens. Later translation results,
    /// source changes, search and visibility settings cannot change this export.
    func makeSubtitleExportSnapshot() throws -> SubtitleExportSnapshot {
        let first: SubtitleTrack
        let second: SubtitleTrack
        let firstOffset: Double
        let secondOffset: Double
        if live.enabled {
            let finalized = live.transcript.captions.filter(\.isFinal)
            first = SubtitleTrack(cues: finalized.map {
                SubtitleCue(id: $0.id, start: $0.start, end: $0.end, text: $0.text)
            })
            second = SubtitleTrack(cues: finalized.compactMap {
                guard let translation = $0.translation, !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return SubtitleCue(id: $0.id, start: $0.start, end: $0.end, text: translation)
            })
            firstOffset = 0; secondOffset = 0
        } else {
            guard !sentencesBuilding else { throw PlayerSubtitleExportError.preparing }
            first = displayTrack(slot: 0); second = displayTrack(slot: 1)
            firstOffset = displayOffset(slot: 0); secondOffset = displayOffset(slot: 1)
        }
        guard !first.cues.isEmpty || !second.cues.isEmpty else { throw PlayerSubtitleExportError.empty }
        let base = mediaURL?.deletingPathExtension().lastPathComponent
            ?? youtube.map { "YouTube-\($0.link.videoID)" }
            ?? slots.first(where: { !$0.track.cues.isEmpty }).map { URL(fileURLWithPath: $0.name).deletingPathExtension().lastPathComponent }
            ?? "AxonTube"
        let safeBase = base.components(separatedBy: CharacterSet(charactersIn: "/:\0")).joined(separator: "-")
        return SubtitleExportSnapshot(primary: first, secondary: second,
            primaryOffset: firstOffset, secondaryOffset: secondOffset,
            sourceURLs: slots.compactMap(\.sourceURL) + [mediaURL].compactMap { $0 },
            suggestedName: String(safeBase.prefix(100)) + ".bilingual.srt",
            isLive: live.enabled)
    }

    func exportBilingualSubtitles() {
        guard !isExportingSubtitles else { return }
        do {
            let snapshot = try makeSubtitleExportSnapshot()
            isExportingSubtitles = true
            let panel = NSSavePanel()
            panel.prompt = L10n.text("Export", "导出")
            panel.title = L10n.text("Export Bilingual Subtitles", "导出双语字幕")
            let formatPicker = SubtitleExportFormatPicker(panel: panel, snapshot: snapshot)
            panel.accessoryView = formatPicker.view
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else {
                isExportingSubtitles = false
                return
            }
            let format = formatPicker.format
            Task { [weak self] in
                do {
                    let output = try await Task.detached(priority: .userInitiated) {
                        try snapshot.write(to: url, format: format)
                    }.value
                    self?.lastExportedSubtitleURL = url
                    self?.notice = LocalizedText("Exported \(output.cueCount) cues · \(url.lastPathComponent)", "已导出 \(output.cueCount) 段字幕 · \(url.lastPathComponent)")
                } catch {
                    self?.errorMessage = LocalizedText("Subtitle export failed: ", "字幕导出失败：") + LocalizedText(error: error)
                }
                self?.isExportingSubtitles = false
            }
        } catch {
            isExportingSubtitles = false
            errorMessage = LocalizedText(error: error)
        }
    }

    /// Media sidecars retain the downloaded cues and both timing corrections.
    /// Reading-mode sentence grouping must not change the saved playback timeline.
    func makeVideoSubtitleSnapshot() -> SubtitleExportSnapshot? {
        guard slots.contains(where: { !$0.track.cues.isEmpty }) else { return nil }
        return SubtitleExportSnapshot(primary: slots[0].track, secondary: slots[1].track,
            primaryOffset: slots[0].offset, secondaryOffset: slots[1].offset,
            sourceURLs: slots.compactMap(\.sourceURL) + [mediaURL].compactMap { $0 },
            suggestedName: "subtitles.bilingual.srt", isLive: false)
    }

    /// Freeze ready tracks immediately. If their current request is still running,
    /// collect that pair while the media downloads, with a bounded wait. The two
    /// offsets belong to the save action; later UI changes cannot alter the copy.
    /// Only results from this video and language selection may enter the save.
    func makeVideoSubtitleSaveProvider(timeout: Duration = .seconds(420)) -> @MainActor @Sendable () async -> SubtitleExportSnapshot? {
        guard isPreparingYouTubeCaptions, let link = youtubeSubtitleLink else {
            let snapshot = makeVideoSubtitleSnapshot()
            return { snapshot }
        }
        let generation = captionSaveGeneration
        let primaryLanguage = primaryCaptionLanguage
        let secondaryLanguage = secondaryCaptionLanguage
        let primaryOffset = slots[0].offset
        let secondaryOffset = slots[1].offset
        func matchingSnapshot(_ result: YouTubeCaptionResult?) -> SubtitleExportSnapshot? {
            guard let result, result.videoID == link.videoID,
                  result.primaryLanguage == primaryLanguage, result.secondaryLanguage == secondaryLanguage else { return nil }
            return SubtitleExportSnapshot(primary: SubtitleTrack(cues: result.primaryCues),
                secondary: SubtitleTrack(cues: result.secondaryCues ?? []),
                primaryOffset: primaryOffset, secondaryOffset: secondaryOffset,
                sourceURLs: [result.primaryURL] + [result.secondaryURL].compactMap { $0 },
                suggestedName: "subtitles.bilingual.srt", isLive: false)
        }
        let initial = matchingSnapshot(lastYouTubeCaptionResult)
        let initialRevision = lastYouTubeCaptionRevision
        let deadline = ContinuousClock.now.advanced(by: timeout)
        return { [weak self] in
            var snapshot = initial
            var revision = initialRevision
            while !Task.isCancelled {
                guard let self, self.captionSaveGeneration == generation,
                      self.youtubeSubtitleLink?.videoID == link.videoID,
                      self.primaryCaptionLanguage == primaryLanguage,
                      self.secondaryCaptionLanguage == secondaryLanguage else { return snapshot }
                // Building tracks sorts their cues. Poll only the inexpensive
                // state flags; rebuild the snapshot when a caption result arrives.
                if revision != self.lastYouTubeCaptionRevision {
                    snapshot = matchingSnapshot(self.lastYouTubeCaptionResult) ?? snapshot
                    revision = self.lastYouTubeCaptionRevision
                }
                if !self.isPreparingYouTubeCaptions || ContinuousClock.now >= deadline { return snapshot }
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return nil }
            }
            return nil
        }
    }

    func saveVideo() {
        guard canSaveVideo else { return }
        let session = mediaSession
        let link = youtube?.link
        let source = mediaURL
        let panel = NSOpenPanel()
        panel.title = L10n.text("Save Video and Subtitles", "保存视频和字幕")
        panel.prompt = L10n.text("Save Here", "保存到此处")
        panel.message = L10n.text("Choose a folder for the video and its synchronized subtitles.", "选择保存视频及同步字幕的文件夹。")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if let path = UserDefaults.standard.string(forKey: "video.lastSaveDirectory") {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        guard panel.runModal() == .OK, let directory = panel.url,
              mediaSession == session, !videoSaver.isSaving else { return }
        UserDefaults.standard.set(directory.path, forKey: "video.lastSaveDirectory")
        let completed: (URL) -> Void = { [weak self] _ in
            guard let self, self.mediaSession == session else { return }
            self.notice = self.videoSaver.status
        }
        if let link {
            videoSaver.save(link: link, subtitleProvider: makeVideoSubtitleSaveProvider(),
                destinationDirectory: directory, completion: completed)
        } else if let source {
            videoSaver.saveLocal(mediaURL: source, snapshot: makeVideoSubtitleSnapshot(), destinationDirectory: directory, completion: completed)
        }
    }

    func openURLs(_ urls: [URL]) {
        if let remote = urls.first(where: { !$0.isFileURL }) {
            do { openYouTube(try YouTubeLink.parse(remote.absoluteString)) }
            catch { errorMessage = LocalizedText(error: error) }
        }
        let subtitleTypes = ["srt", "vtt", "ass", "ssa"]
        let media = urls.filter { !subtitleTypes.contains($0.pathExtension.lowercased()) && $0.isFileURL }
        if let first = media.first { openMedia(first) }
        let subtitleURLs = urls.filter { subtitleTypes.contains($0.pathExtension.lowercased()) && $0.isFileURL }
        for (index, url) in subtitleURLs.prefix(2).enumerated() {
            let slot = subtitleURLs.count == 1 ? (slots[0].track.cues.isEmpty ? 0 : 1) : index
            loadSubtitle(url, slot: slot)
        }
    }

    func openMedia(_ url: URL, retainSubtitles: Bool = false) {
        guard url.isFileURL else { errorMessage = LocalizedText("Choose a local media file.", "此版本只打开本地文件。"); return }
        cancelCaptionWork()
        youtubeSubtitleLink = nil
        live.configureSource(url: url, youtube: false)
        lastYouTubeTick = nil
        youtube?.invalidate()
        youtube = nil
        youtubeReady = false
        youtubeMessage = nil
        player.pause()
        player.volume = Float(volume)
        mediaSession = UUID()
        let session = mediaSession
        mediaURL = url
        localPlaybackEnded = false
        localSeeking = false
        seekSession = UUID()
        currentTime = 0
        duration = 0
        isLoading = true
        notice = LocalizedText("Opening local media…", "正在读取本地媒体…")
        loopEnabled = false
        loopCueID = nil
        search = ""
        errorMessage = nil
        lastConvertedURL = nil
        if !retainSubtitles { slots = [SubtitleSlot(), SubtitleSlot()]; selectedPanel = 0 }
        statusObservation = nil
        if let observer = endObserver { NotificationCenter.default.removeObserver(observer); endObserver = nil }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            let status = observed.status
            let message = observed.error?.localizedDescription
            Task { @MainActor in
                guard let self, self.mediaSession == session else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.notice = self.lastConvertedURL == nil ? LocalizedText("Ready · Choose a subtitle to start practicing", "媒体已就绪 · 使用字幕列表开始逐句学习") : LocalizedText("Compatible copy ready · Original file preserved", "兼容副本已就绪，原视频保留不变")
                    self.player.playImmediately(atRate: Float(self.speed))
                case .failed:
                    self.isLoading = false
                    self.notice = LocalizedText("Unsupported media · Try Convert", "系统无法直接播放 · 可尝试兼容转换")
                    self.errorMessage = LocalizedText("This file cannot be played directly. Use Convert to create an H.264 / AAC MP4 copy.\n\n", "系统无法直接播放此文件。可使用顶部“兼容转换”制作 H.264 / AAC 的 MP4 副本。\n\n") + (message.map { LocalizedText(verbatim: $0) } ?? LocalizedText("Unsupported format or codec.", "格式或编码不受支持。"))
                default: break
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.mediaSession == session else { return }
                self.localPlaybackEnded = true
                if self.loopEnabled, let cue = self.loopCue {
                    self.seek(to: cue.start + self.loopOffset, preserveLoop: true)
                    self.player.playImmediately(atRate: Float(self.speed))
                } else { self.isPlaying = false }
            }
        }
        if !retainSubtitles { loadAdjacentSubtitles(for: url) }
    }

    private func loadAdjacentSubtitles(for url: URL) {
        // Only inspect the opened video's directory for matching sidecar filenames.
        let base = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let candidates = files.filter {
            ["srt", "vtt", "ass", "ssa"].contains($0.pathExtension.lowercased()) &&
            ($0.deletingPathExtension().lastPathComponent == base || $0.lastPathComponent.hasPrefix(base + "."))
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        for (index, subtitle) in candidates.prefix(2).enumerated() { loadSubtitle(subtitle, slot: index) }
    }

    func loadSubtitle(_ url: URL, slot: Int) {
        do {
            let cues = try SubtitleParser.read(url: url)
            cancelCaptionWork()
            if live.enabled { live.stop(); live.enabled = false }
            slots[slot] = SubtitleSlot(name: url.lastPathComponent, track: SubtitleTrack(cues: cues), sourceURL: url)
            if slot == activeSlot { loopEnabled = false; loopCueID = nil }
            notice = LocalizedText("Loaded \(url.lastPathComponent) · \(cues.count) cues", "已载入 \(url.lastPathComponent) · \(cues.count) 句")
        } catch { errorMessage = LocalizedText("Could not read subtitles: ", "字幕读取失败：") + LocalizedText(error: error) }
    }

    func clearSubtitle(slot: Int) {
        cancelCaptionWork()
        slots[slot] = SubtitleSlot()
        loopEnabled = false
        loopCueID = nil
    }

    func activeText(slot: Int) -> String {
        guard slots[slot].isVisible else { return "" }
        if live.enabled {
            if slot == 1 && !live.chineseEnabled { return "" }
            if live.running {
                return slot == 0 ? live.currentText : live.currentTranslation
            }
            let captions = live.transcript.captions.filter { $0.start <= currentTime && $0.end > currentTime }
            return captions.compactMap { slot == 0 ? $0.text : $0.translation }.joined(separator: "\n")
        }
        return displayTrack(slot: slot).activeCues(at: currentTime - displayOffset(slot: slot)).map(\.text).joined(separator: "\n")
    }

    func pairedText(for cue: SubtitleCue) -> String {
        if live.enabled { return live.chineseEnabled ? live.transcript.captions.first(where: { $0.id == cue.id })?.translation ?? "" : "" }
        let other = activeSlot == 0 ? 1 : 0
        if usingSentenceTracks {
            // The builder assigns each translation once. Keep that pairing even
            // though each language retains its own corrected playback interval.
            return sentenceTextByID[other][cue.id] ?? ""
        }
        let delta = learningOffset - displayOffset(slot: other)
        let candidates = displayTrack(slot: other).overlappingCues(start: cue.start + delta, end: cue.end + delta)
        // Ignore tiny edge overlaps caused by normal differences between translations.
        let ranked = candidates.map { candidate in
            (candidate, max(0, min(cue.end + delta, candidate.end) - max(cue.start + delta, candidate.start)))
        }
        let best = ranked.map(\.1).max() ?? 0
        return ranked.filter { $0.1 >= min(0.35, best) && $0.1 >= best * 0.25 }.map { $0.0.text }.joined(separator: "\n")
    }

    private func rebuildSentenceTracks() {
        sentenceTask?.cancel()
        sentenceWorker?.cancel()
        let token = UUID()
        sentenceGeneration = token
        guard sentenceMode, slots.contains(where: { !$0.track.cues.isEmpty }) else {
            sentenceTracks = nil
            sentenceTextByID = [[:], [:]]
            sentencesBuilding = false
            return
        }
        let source = slots
        sentencesBuilding = true
        sentenceTask = Task { [weak self] in
            // Coalesce consecutive changes, including the two progressive tracks.
            do { try await Task.sleep(for: .milliseconds(25)) } catch { return }
            guard let self, !Task.isCancelled, self.sentenceGeneration == token else { return }
            let worker = Task.detached(priority: .userInitiated) {
                func shifted(_ slot: SubtitleSlot) -> [SubtitleCue] {
                    slot.track.cues.compactMap { cue in
                        let start = max(0, cue.start + slot.offset)
                        let end = cue.end + slot.offset
                        guard end > start else { return nil }
                        return SubtitleCue(id: cue.id, start: start, end: end, text: cue.text)
                    }
                }
                return SubtitleSentenceBuilder.build(english: shifted(source[0]), chinese: shifted(source[1]))
            }
            self.sentenceWorker = worker
            let result = await worker.value
            guard !Task.isCancelled, self.sentenceGeneration == token else { return }
            let tracks = [result.english, result.chinese]
            self.sentenceTextByID = tracks.map { Dictionary(uniqueKeysWithValues: $0.cues.map { ($0.id, $0.text) }) }
            self.sentenceTracks = tracks
            self.sentencesBuilding = false
            self.sentenceWorker = nil
        }
    }

    func togglePlayback() {
        if let youtube {
            guard youtubeReady else { return }
            if isPlaying { youtube.pause(); isPlaying = false }
            else {
                if duration > 0 && currentTime >= duration - 0.08 { seek(to: 0) }
                youtube.play()
            }
            return
        }
        guard player.currentItem != nil else { chooseVideo(); return }
        if isPlaying { player.pause(); isPlaying = false }
        else {
            if duration > 0 && currentTime >= duration - 0.08 { seek(to: 0) }
            player.playImmediately(atRate: Float(speed))
            isPlaying = true
        }
    }

    func seek(to seconds: Double, preserveLoop: Bool = false) {
        guard seconds.isFinite else { return }
        localPlaybackEnded = false
        if !preserveLoop { loopEnabled = false; loopCueID = nil }
        let target = min(max(0, seconds), duration > 0 ? duration : .greatestFiniteMagnitude)
        if let youtube {
            youtubeAudioPlaying = false
            pendingYouTubeSeek = (target, Date())
            youtube.seek(target)
        }
        else {
            localSeeking = true
            let id = UUID(); seekSession = id
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.seekSession == id else { return }
                    self.localSeeking = false
                }
            }
        }
        currentTime = target
        lastYouTubeTick = nil
        live.didSeek()
    }

    func playCue(_ cue: SubtitleCue) {
        guard isReady else { notice = LocalizedText("Open a playable video first", "请先打开可播放的视频"); return }
        guard cue.start + learningOffset < duration || duration <= 0 else { notice = LocalizedText("This subtitle starts after the video ends. Check its timing offset.", "这句字幕位于视频结束之后，请检查字幕时间偏移"); return }
        if loopEnabled { loopCueID = cue.id; loopCueSnapshot = cue; loopSnapshotOffset = learningOffset }
        seek(to: cue.start + learningOffset, preserveLoop: loopEnabled)
        resumePlayback()
        isPlaying = true
    }

    func previousCue() {
        let reference = currentCue?.start ?? (currentTime - learningOffset)
        if let index = learningTrack.previousIndex(at: reference) { playCue(learningTrack.cues[index]) }
    }

    func nextCue() {
        if let index = learningTrack.nextIndex(at: currentTime - learningOffset) { playCue(learningTrack.cues[index]) }
    }

    func replayCue() {
        if let cue = currentCue { playCue(cue) }
        else if let index = learningTrack.previousIndex(at: currentTime - learningOffset) { playCue(learningTrack.cues[index]) }
    }

    func toggleLoop() {
        if loopEnabled { loopEnabled = false; loopCueID = nil; return }
        guard isReady else { notice = LocalizedText("Open a playable video first", "请先打开可播放的视频"); return }
        guard let cue = currentCue ?? learningTrack.previousIndex(at: currentTime - learningOffset).map({ learningTrack.cues[$0] }) ?? learningTrack.cues.first else { return }
        loopCueID = cue.id
        loopEnabled = true
        playCue(cue)
    }

    func setSpeed(_ value: Double) {
        if let youtube { youtube.rate(value) }
        else { speed = value; if isPlaying { player.rate = Float(value) } }
    }
    func setVolume(_ value: Double) {
        volume = value
        if let youtube { youtube.volume(value) } else { player.volume = Float(value) }
    }
    func selectPanel(_ value: Int) {
        if live.enabled { live.stop(); live.enabled = false }
        selectedPanel = value; loopEnabled = false; loopCueID = nil
    }

    private func resumePlayback() {
        if let youtube { youtube.play() }
        else { player.playImmediately(atRate: Float(speed)) }
    }

    func openYouTube(_ link: YouTubeLink, retainSubtitles: Bool = false) {
        let sameVideo = youtube?.link.videoID == link.videoID
        youtubeAudioPlaying = false
        pendingYouTubeSeek = nil
        localSeeking = false
        seekSession = UUID()
        live.configureSource(url: nil, youtube: true)
        lastYouTubeTick = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObservation = nil
        if let observer = endObserver { NotificationCenter.default.removeObserver(observer); endObserver = nil }
        youtube?.invalidate()
        mediaSession = UUID()
        let session = mediaSession
        mediaURL = nil
        currentTime = link.startTime
        duration = 0
        isPlaying = false
        isLoading = true
        youtubeReady = false
        youtubeMessage = nil
        youtubeRates = [1]
        speed = 1
        errorMessage = nil
        lastConvertedURL = nil
        loopEnabled = false
        loopCueID = nil
        search = ""
        if !sameVideo { slots = [SubtitleSlot(), SubtitleSlot()]; selectedPanel = 0 }
        notice = LocalizedText("Connecting to YouTube · No AI API tokens required", "正在连接 YouTube · 在线播放不消耗 AI token")
        let controller = YouTubeController(link: link)
        controller.onReady = { [weak self, weak controller] in
            guard let self, self.mediaSession == session else { return }
            self.youtubeReady = true
            self.isLoading = false
            self.youtubeMessage = nil
            self.notice = LocalizedText("YouTube ready · Click to play; use your browser for account-only videos", "YouTube 已就绪 · 点击画面播放；账号视频可在浏览器观看")
            controller?.volume(self.volume)
        }
        controller.onUpdate = { [weak self] state in
            guard let self, self.mediaSession == session else { return }
            if let pending = self.pendingYouTubeSeek {
                if abs(state.time - pending.target) > 1, Date().timeIntervalSince(pending.requested) < 3 {
                    self.youtubeAudioPlaying = false
                    return
                }
                self.pendingYouTubeSeek = nil
            }
            let previous = self.lastYouTubeTick
            let wall = Date()
            self.currentTime = state.time
            self.duration = state.duration
            self.isPlaying = state.state == 1 || state.state == 3
            self.youtubeAudioPlaying = state.state == 1
            self.speed = state.rate
            self.lastYouTubeTick = (state.time, wall, state.rate)
            if let previous, self.live.enabled {
                let expected = max(0, wall.timeIntervalSince(previous.wall)) * previous.rate
                if abs(state.time - previous.time) > max(1.2, expected + 0.8) || abs(state.rate - previous.rate) > 0.01 {
                    self.live.didSeek()
                }
            }
            if !state.rates.isEmpty { self.youtubeRates = state.rates }
            if state.state == 1 { self.youtubeMessage = nil; self.checkLoop(at: state.time) }
            if state.state == 0, self.loopEnabled, let cue = self.loopCue {
                self.seek(to: cue.start + self.loopOffset, preserveLoop: true)
                self.resumePlayback()
            }
            else if state.state == 0 { self.live.finishYouTube() }
        }
        controller.onError = { [weak self] message in
            guard let self, self.mediaSession == session else { return }
            self.isLoading = false
            self.youtubeMessage = message
            self.notice = LocalizedText("YouTube playback restricted · See the official player message", "YouTube 播放受限 · 请查看视频画面中的官方提示")
        }
        youtube = controller
        controller.load()
        beginYouTubeSubtitleSession(link)
    }

    func reloadYouTube() {
        if let link = youtube?.link { openYouTube(link, retainSubtitles: true) }
    }

    /// Opening a video starts its captions once. Reloading the same embedded
    /// player keeps both downloaded captions and an in-flight translation.
    func beginYouTubeSubtitleSession(_ link: YouTubeLink) {
        let sameVideo = youtubeSubtitleLink?.videoID == link.videoID
        if !sameVideo {
            cancelCaptionWork()
            youtubeSubtitleLink = link
            slots = [SubtitleSlot(), SubtitleSlot()]
            selectedPanel = 0
        }
        if sameVideo && (youtubeCaptions.isFetching || captionSelectionTask != nil
                        || slots.contains(where: { !$0.track.cues.isEmpty })) { return }
        fetchYouTubeCaptions()
    }

    private func cancelCaptionWork() {
        captionSelectionTask?.cancel()
        captionSelectionTask = nil
        captionRequestGeneration = UUID()
        captionSaveGeneration = UUID()
        youtubeCaptions.cancel()
    }

    private func captionLanguageChanged() {
        cancelCaptionWork()
        guard let link = youtubeSubtitleLink else { return }
        // Coalesce two quick picker changes into one pair request.
        let generation = captionRequestGeneration
        captionSelectionTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            guard let self, !Task.isCancelled, self.captionRequestGeneration == generation,
                  self.youtubeSubtitleLink?.videoID == link.videoID else { return }
            self.captionSelectionTask = nil
            self.fetchYouTubeCaptions()
        }
    }

    func fetchYouTubeCaptions() {
        guard let link = youtubeSubtitleLink, !youtubeCaptions.isFetching else { return }
        captionSelectionTask?.cancel()
        captionSelectionTask = nil
        let generation = UUID()
        captionRequestGeneration = generation
        var installedPrimary = false
        live.stop()
        live.enabled = false
        let primaryLanguage = primaryCaptionLanguage
        let secondaryLanguage = secondaryCaptionLanguage
        youtubeCaptions.fetch(link: link, primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage) { [weak self] result in
            guard let self, self.captionRequestGeneration == generation,
                  self.youtubeSubtitleLink?.videoID == result.videoID,
                  result.primaryLanguage == primaryLanguage, result.secondaryLanguage == secondaryLanguage,
                  self.primaryCaptionLanguage == primaryLanguage, self.secondaryCaptionLanguage == secondaryLanguage else { return }
            self.lastYouTubeCaptionResult = result
            self.lastYouTubeCaptionRevision = UUID()
            if !installedPrimary {
                var updated = self.slots
                updated[0].name = "YouTube · \(result.primaryTrack.languageCode)"
                updated[0].websiteTrack = result.primaryTrack
                updated[0].track = SubtitleTrack(cues: result.primaryCues)
                updated[0].sourceURL = result.primaryURL
                // A refresh must not discard a usable translation before its
                // replacement has actually downloaded. Its label stays accurate.
                self.slots = updated
                self.selectedPanel = 0
                self.loopEnabled = false
                self.loopCueID = nil
                self.search = ""
                installedPrimary = true
            }
            if let secondary = result.secondaryCues {
                self.slots[1].name = "YouTube · \(result.secondaryTrack?.languageCode ?? secondaryLanguage)"
                self.slots[1].websiteTrack = result.secondaryTrack
                self.slots[1].track = SubtitleTrack(cues: secondary)
                self.slots[1].sourceURL = result.secondaryURL
            }
            self.notice = result.warning ?? (result.secondaryURL == nil
                ? LocalizedText("First subtitle ready · Preparing the second subtitle", "第一字幕已就绪 · 正在准备第二字幕")
                : LocalizedText("Bilingual captions ready · \(self.slots[0].track.cues.count) / \(self.slots[1].track.cues.count) cues", "双语字幕已就绪 · \(self.slots[0].track.cues.count) / \(self.slots[1].track.cues.count) 段"))
            if result.isComplete, result.secondaryCues == nil, !self.slots[1].track.cues.isEmpty {
                self.notice = self.notice + LocalizedText(" The previous second subtitle is still available.", " 原有第二字幕仍可使用。")
            }
        }
    }

    func cancelYouTubeCaptions() {
        cancelCaptionWork()
        notice = LocalizedText("Caption retrieval canceled · Loaded captions remain available", "已取消 YouTube 字幕获取 · 已载入的字幕仍可使用")
    }

    func openYouTubeInBrowser() {
        openYouTubeInBrowser(link: youtube?.link)
    }

    func openYouTubeInBrowser(link: YouTubeLink?) {
        youtube?.pause()
        isPlaying = false
        let url = link?.canonicalURL ?? URL(string: "https://www.youtube.com/")!
        NSWorkspace.shared.open(url)
    }

    func openDemo() {
        let base = Bundle.main.resourceURL?.appendingPathComponent("Samples")
        guard let url = base?.appendingPathComponent("demo.mp4"), FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = LocalizedText("The demo is available in the packaged app. Run scripts/package.sh, then open AxonTube.app in dist.", "示例视频尚未随此运行方式打包。请运行 scripts/package.sh，再打开 dist 中的应用。")
            return
        }
        openMedia(url)
    }

    func revealSource() {
        if let url = mediaURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    func cancelConversion() {
        guard let process = conversion else { return }
        conversionSession = UUID()
        if process.isRunning { process.terminate() }
        conversion = nil
        isConverting = false
        conversionProgress = nil
        notice = LocalizedText("Conversion canceled · Original file preserved", "已取消转换，原视频未修改")
    }

    func convertMedia() {
        guard !isConverting, let input = mediaURL else { return }
        guard let executable = ffmpegURL else {
            errorMessage = LocalizedText("Conversion requires a local FFmpeg installation in /opt/homebrew/bin or /usr/local/bin. Playback and subtitles do not require it.", "兼容转换需要本机 FFmpeg。当前未在 /opt/homebrew/bin 或 /usr/local/bin 找到；普通播放和字幕功能不需要安装它。")
            return
        }
        do {
            let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("io.github.axonvoss-labs.axontube/Converted", isDirectory: true)
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            let output = cache.appendingPathComponent(input.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString.prefix(8) + ".mp4")
            let id = UUID()
            let sourceSession = mediaSession
            conversionSession = id
            player.pause()
            isPlaying = false
            isConverting = true
            conversionProgress = nil
            let process = Process()
            let pipe = Pipe()
            process.executableURL = executable
            process.arguments = ["-nostdin", "-v", "error", "-progress", "pipe:1", "-i", input.path,
                                 "-map", "0:v:0?", "-map", "0:a:0?", "-c:v", "libx264", "-preset", "veryfast", "-crf", "21",
                                 "-pix_fmt", "yuv420p", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:a", "aac", "-b:a", "192k",
                                 "-movflags", "+faststart", "-n", output.path]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            let mediaDuration = duration
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                let value = text.split(separator: "\n").last(where: { $0.hasPrefix("out_time_us=") }).flatMap { Double($0.dropFirst(12)) }
                if let value, mediaDuration > 0 {
                    Task { @MainActor in
                        guard let self, self.conversionSession == id else { return }
                        self.conversionProgress = min(1, value / 1_000_000 / mediaDuration)
                    }
                }
            }
            process.terminationHandler = { [weak self] process in
                pipe.fileHandleForReading.readabilityHandler = nil
                Task { @MainActor in
                    guard let self, self.conversionSession == id else { return }
                    self.isConverting = false
                    self.conversionProgress = nil
                    self.conversion = nil
                    if process.terminationStatus == 0 {
                        if self.mediaSession == sourceSession {
                            self.openMedia(output, retainSubtitles: true)
                        }
                        self.lastConvertedURL = output
                        self.notice = LocalizedText("Compatible copy saved · Original file preserved", "兼容副本已保存，原视频保留不变")
                    } else {
                        self.errorMessage = LocalizedText("Conversion failed. The file may be damaged, have no usable tracks, or require an unavailable FFmpeg encoder. The original is unchanged.", "兼容转换失败。文件可能损坏、无可用音视频轨道，或本机 FFmpeg 缺少编码器。原文件未修改。")
                    }
                }
            }
            conversion = process
            try process.run()
            notice = LocalizedText("Creating a compatible copy locally · Long videos may take a while", "正在本机制作兼容副本；长视频可能需要较长时间")
        } catch {
            isConverting = false
            conversion = nil
            errorMessage = LocalizedText("Could not start conversion: ", "无法启动兼容转换：") + LocalizedText(error: error)
        }
    }
}

func timeLabel(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "00:00" }
    let total = max(0, Int(seconds))
    if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60) }
    return String(format: "%02d:%02d", total / 60, total % 60)
}
