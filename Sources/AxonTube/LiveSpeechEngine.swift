import AVFoundation
import Foundation
import PlayerCore
import Speech

private final class SpeechPCMConverterInput: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private let lock = NSLock()
    private var supplied = false

    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }

    func take() -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }
        guard !supplied else { return nil }
        supplied = true
        return buffer
    }
}

enum LiveSpeechModelStatus: Equatable, Sendable {
    case unavailable, unsupported, notInstalled, downloading, installed
}

struct LiveSpeechModelInfo: Sendable {
    let status: LiveSpeechModelStatus
    let localeIdentifier: String
    let message: LocalizedText
}

struct LiveSpeechResult: Sendable {
    let text: String
    let range: CMTimeRange
    let isFinal: Bool
    let finalizedThrough: CMTime
}

enum LiveSpeechError: BilingualError {
    case unavailable, unsupportedLanguage, modelRequired, audioFormat, inactive, discontinuousAudio, conversion(LocalizedText)

    var message: LocalizedText {
        switch self {
        case .unavailable: return LocalizedText("This Mac does not currently support Apple's on-device speech recognition.", "这台 Mac 暂不支持 Apple 本地语音识别。")
        case .unsupportedLanguage: return LocalizedText("The on-device speech engine does not currently support the selected language.", "本地语音引擎暂不支持所选语言。")
        case .modelRequired: return LocalizedText("Download the on-device speech model for this language first.", "需要先下载所选语言的本地识别模型。")
        case .audioFormat: return LocalizedText("The audio format required for live transcription could not be prepared.", "无法准备实时识别所需的音频格式。")
        case .inactive: return LocalizedText("Live transcription has stopped.", "实时识别已停止。")
        case .discontinuousAudio: return LocalizedText("Audio timestamps moved backwards. Restart live transcription.", "音频时间发生回退，请重新启动实时听写。")
        case .conversion(let detail): return LocalizedText("Live audio conversion failed: ", "实时音频转换失败：") + detail
        }
    }
}

/// On-device transcription only. No microphone, capture or cloud API is used here.
@available(macOS 26.0, *)
@MainActor
final class LiveSpeechEngine {
    let localeIdentifier: String
    private(set) var audioFormat: AVAudioFormat?
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Error>?
    private var converter: AVAudioConverter?
    private var sessionID = UUID()
    private var acceptingAudio = false
    private var nextAudioTime: CMTime?

    init(localeIdentifier: String = "en-US") {
        self.localeIdentifier = localeIdentifier
    }

    private static func module(for locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)
    }

    static func supportedLanguageOptions() async -> [SpeechLanguageOption] {
        guard SpeechTranscriber.isAvailable else { return [] }
        return SpeechLanguageSettings.options(identifiers: await SpeechTranscriber.supportedLocales.map(\.identifier))
    }

    private static func supportedLocale(identifier: String) async -> Locale? {
        let locales = await SpeechTranscriber.supportedLocales
        return locales.first {
            SpeechLanguageSettings.canonicalIdentifier($0.identifier) == SpeechLanguageSettings.canonicalIdentifier(identifier)
        }
    }

    /// This checks the exact requested model configuration, not just installedLocales.
    /// It never requests a reservation or a download.
    static func checkModel(localeIdentifier: String) async -> LiveSpeechModelInfo {
        guard SpeechTranscriber.isAvailable else {
            return .init(status: .unavailable, localeIdentifier: localeIdentifier,
                         message: LocalizedText("This device does not currently support on-device live transcription.", "当前设备暂不支持本地实时语音识别。"))
        }
        guard let locale = await supportedLocale(identifier: localeIdentifier) else {
            return .init(status: .unsupported, localeIdentifier: localeIdentifier,
                         message: LocalizedText("The system reports no available model for this language. Try again later or choose another language.", "系统未报告此语言的可用模型，请稍后重试或选择其他语言。"))
        }
        let status = await AssetInventory.status(forModules: [module(for: locale)])
        switch status {
        case .installed:
            return .init(status: .installed, localeIdentifier: locale.identifier,
                         message: LocalizedText("The on-device speech model is ready. Transcription uses no AI API tokens.", "本地实时识别模型已就绪；识别不消耗 AI token。"))
        case .supported:
            return .init(status: .notInstalled, localeIdentifier: locale.identifier,
                         message: LocalizedText("Download Apple's language model before first use. Transcription can then run offline.", "首次使用需要下载 Apple 语言模型，之后可离线识别。"))
        case .downloading:
            return .init(status: .downloading, localeIdentifier: locale.identifier,
                         message: LocalizedText("The language model is downloading or waiting for the system to finish.", "语言模型正在下载或等待系统完成下载。"))
        case .unsupported:
            return .init(status: .unsupported, localeIdentifier: locale.identifier,
                         message: LocalizedText("The system does not currently support this live transcription configuration.", "系统暂不支持此实时识别配置。"))
        @unknown default:
            return .init(status: .unavailable, localeIdentifier: locale.identifier,
                         message: LocalizedText("The speech model status is currently unavailable.", "暂时无法确认语音模型状态。"))
        }
    }

    /// Call only from an explicit user action. Apple manages the shared model assets.
    func installModel(onProgress: @escaping @MainActor @Sendable (Double) -> Void = { _ in }) async throws {
        guard SpeechTranscriber.isAvailable else { throw LiveSpeechError.unavailable }
        guard let locale = await Self.supportedLocale(identifier: localeIdentifier) else {
            throw LiveSpeechError.unsupportedLanguage
        }
        let transcriber = Self.module(for: locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            let progress = request.progress
            let progressTask = Task { @MainActor in
                while !Task.isCancelled {
                    onProgress(progress.fractionCompleted)
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            defer { progressTask.cancel() }
            try await request.downloadAndInstall()
        }
        onProgress(1)
    }

    @discardableResult
    func start(
        onResult: @escaping @MainActor @Sendable (LiveSpeechResult) -> Void,
        onError: @escaping @MainActor @Sendable (Error) -> Void
    ) async throws -> AVAudioFormat {
        await cancel()
        let id = UUID()
        sessionID = id
        guard SpeechTranscriber.isAvailable else { throw LiveSpeechError.unavailable }
        guard let locale = await Self.supportedLocale(identifier: localeIdentifier) else {
            throw LiveSpeechError.unsupportedLanguage
        }
        let transcriber = Self.module(for: locale)
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
            throw LiveSpeechError.modelRequired
        }
        _ = try await AssetInventory.reserve(locale: locale)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw LiveSpeechError.audioFormat
        }
        try Task.checkCancellation()
        guard id == sessionID else { throw CancellationError() }
        let newAnalyzer = SpeechAnalyzer(modules: [transcriber])
        let (input, builder) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingOldest(8))
        analyzer = newAnalyzer
        continuation = builder
        audioFormat = format
        converter = nil
        nextAudioTime = nil
        resultTask = Task { @MainActor [weak self] in
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    guard let self, self.sessionID == id else { return }
                    onResult(.init(text: String(result.text.characters), range: result.range,
                                   isFinal: result.isFinal, finalizedThrough: result.resultsFinalizationTime))
                }
            } catch {
                if let self, self.sessionID == id, !Task.isCancelled {
                    self.acceptingAudio = false
                    self.continuation?.finish()
                    onError(error)
                }
                throw error
            }
        }
        do {
            try await newAnalyzer.prepareToAnalyze(in: format)
            try Task.checkCancellation()
            guard id == sessionID else { throw CancellationError() }
            try await newAnalyzer.start(inputSequence: input)
            guard id == sessionID else { throw CancellationError() }
            acceptingAudio = true
            return format
        } catch {
            if id == sessionID { await cancel() }
            throw error
        }
    }

    /// Appends owned PCM storage. The caller must not mutate it after this call.
    /// Bounded buffering waits for capacity rather than dropping spoken audio.
    func append(_ buffer: AVAudioPCMBuffer, mediaTime: CMTime) async throws {
        guard acceptingAudio, let target = audioFormat else { throw LiveSpeechError.inactive }
        guard buffer.frameLength > 0 else { return }
        let id = sessionID
        if buffer.format == target {
            try await enqueue(buffer, at: mediaTime, session: id)
            return
        }
        if converter?.inputFormat != buffer.format || converter?.outputFormat != target {
            converter = AVAudioConverter(from: buffer.format, to: target)
        }
        guard let converter else { throw LiveSpeechError.audioFormat }
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate)) + 64
        let source = SpeechPCMConverterInput(buffer)
        var nextTime = mediaTime
        while true {
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: max(capacity, 64)) else {
                throw LiveSpeechError.audioFormat
            }
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, inputStatus in
                guard let input = source.take() else {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                inputStatus.pointee = .haveData
                return input
            }
            if let error { throw LiveSpeechError.conversion(LocalizedText(error: error)) }
            if status == .error { throw LiveSpeechError.conversion(LocalizedText("PCM audio could not be converted.", "无法转换 PCM 音频")) }
            if output.frameLength > 0 {
                try await enqueue(output, at: nextTime, session: id)
                nextTime = CMTimeAdd(nextTime, CMTime(value: CMTimeValue(output.frameLength), timescale: CMTimeScale(target.sampleRate.rounded())))
            }
            if status == .inputRanDry || status == .endOfStream || output.frameLength == 0 { break }
        }
    }

    private func enqueue(_ buffer: AVAudioPCMBuffer, at time: CMTime, session: UUID) async throws {
        while true {
            try Task.checkCancellation()
            guard acceptingAudio, sessionID == session, let continuation else { throw LiveSpeechError.inactive }
            let scale = CMTimeScale(buffer.format.sampleRate.rounded())
            var aligned = CMTimeConvertScale(time, timescale: scale, method: .roundHalfAwayFromZero)
            if let expected = nextAudioTime {
                let difference = CMTimeSubtract(aligned, expected).seconds
                // Packet clocks and sample-rate conversion can round by one sample.
                // Only absorb tiny rounding differences; a real backward seek needs a new session.
                if abs(difference) <= 0.001 { aligned = expected }
                else if difference < 0 { throw LiveSpeechError.discontinuousAudio }
            }
            switch continuation.yield(AnalyzerInput(buffer: buffer, bufferStartTime: aligned)) {
            case .enqueued:
                nextAudioTime = CMTimeAdd(aligned, CMTime(value: CMTimeValue(buffer.frameLength), timescale: scale))
                return
            case .dropped:
                try await Task.sleep(for: .milliseconds(10))
            case .terminated: throw LiveSpeechError.inactive
            @unknown default: throw LiveSpeechError.inactive
            }
        }
    }

    func finish() async throws {
        guard let analyzer else { return }
        let id = sessionID
        acceptingAudio = false
        continuation?.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await resultTask?.value
        if id == sessionID {
            self.analyzer = nil
            continuation = nil
            resultTask = nil
            converter = nil
            audioFormat = nil
            nextAudioTime = nil
        }
    }

    func cancel() async {
        sessionID = UUID()
        acceptingAudio = false
        continuation?.finish()
        continuation = nil
        let previousAnalyzer = analyzer
        let previousResults = resultTask
        analyzer = nil
        resultTask = nil
        converter = nil
        audioFormat = nil
        nextAudioTime = nil
        previousResults?.cancel()
        await previousAnalyzer?.cancelAndFinishNow()
    }
}
