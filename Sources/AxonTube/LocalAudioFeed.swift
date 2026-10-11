import AVFoundation
import Foundation
import PlayerCore

struct LocalAudioClock: Sendable {
    let time: Double
    let isPlaying: Bool
    let hasEnded: Bool

    init(time: Double, isPlaying: Bool, hasEnded: Bool = false) {
        self.time = time
        self.isPlaying = isPlaying
        self.hasEnded = hasEnded
    }
}

enum LocalAudioFeedError: BilingualError {
    case localFileRequired, noAudio, unsupportedFormat, reader(LocalizedText), copy(OSStatus)
    var message: LocalizedText {
        switch self {
        case .localFileRequired: return LocalizedText("On-device transcription reads only the currently open local media file.", "本地实时识别只读取当前打开的本地媒体文件。")
        case .noAudio: return LocalizedText("This file has no audio track available for transcription.", "这个文件没有可识别的音轨。")
        case .unsupportedFormat: return LocalizedText("This audio track cannot be decoded into the PCM format required for live transcription.", "无法将这个音轨解码为实时识别所需的 PCM 音频。")
        case .reader(let detail): return LocalizedText("Live audio reading failed: ", "读取实时音频失败：") + detail
        case .copy(let status): return LocalizedText("Live audio copying failed (\(status)).", "复制实时音频失败（\(status)）。")
        }
    }
}

/// Reads in short chunks and feeds only the portion the AVPlayer clock has played.
/// The owner recreates this feed after any seek, loop or source change.
@MainActor
final class LocalAudioFeed {
    private var task: Task<Void, Never>?
    private var reader: LocalPCMReader?
    private var sessionID = UUID()

    func start(
        url: URL,
        startTime: Double,
        targetFormat: AVAudioFormat,
        clock: @escaping @MainActor @Sendable () -> LocalAudioClock,
        onBuffer: @escaping @MainActor @Sendable (AVAudioPCMBuffer, CMTime) async throws -> Void,
        onFinish: @escaping @MainActor @Sendable () async -> Void,
        onError: @escaping @MainActor @Sendable (Error) -> Void
    ) async throws {
        cancel()
        let id = UUID()
        sessionID = id
        guard url.isFileURL else { throw LocalAudioFeedError.localFileRequired }
        let newReader = LocalPCMReader()
        try await newReader.prepare(url: url, startTime: max(0, startTime), format: targetFormat)
        try Task.checkCancellation()
        guard id == sessionID else {
            await newReader.cancel()
            throw CancellationError()
        }
        reader = newReader
        task = Task { @MainActor [weak self] in
            do {
                while !Task.isCancelled {
                    guard let self, self.sessionID == id else { return }
                    let position = clock()
                    guard position.time.isFinite else {
                        try await Task.sleep(for: .milliseconds(40))
                        continue
                    }
                    let step = try await newReader.next(upTo: position.time, playing: position.isPlaying, hasEnded: position.hasEnded)
                    try Task.checkCancellation()
                    guard self.sessionID == id else { return }
                    switch step {
                    case .buffer(let chunk):
                        try await onBuffer(chunk.buffer, chunk.time)
                    case .waiting:
                        try await Task.sleep(for: .milliseconds(35))
                    case .finished:
                        await newReader.cancel()
                        self.reader = nil
                        self.task = nil
                        await onFinish()
                        return
                    }
                }
            } catch {
                await newReader.cancel()
                if let self, self.sessionID == id, !Task.isCancelled {
                    self.reader = nil
                    self.task = nil
                    onError(error)
                }
            }
        }
    }

    func cancel() {
        sessionID = UUID()
        task?.cancel()
        task = nil
        if let reader { Task { await reader.cancel() } }
        reader = nil
    }
}

private struct LocalPCMChunk: @unchecked Sendable {
    // This PCM buffer has independent owned storage and crosses actors once.
    let buffer: AVAudioPCMBuffer
    let time: CMTime
}

private enum LocalPCMReadStep: Sendable {
    case buffer(LocalPCMChunk), waiting, finished
}

/// AVAssetReader operations are confined to this actor, away from the UI executor.
private actor LocalPCMReader {
    private var reader: AVAssetReader?
    private var output: AVAssetReaderAudioMixOutput?
    private var pending: CMSampleBuffer?
    private var consumedFrames: Int = 0
    private var mediaDuration = Double.infinity
    private var minimumTime: Double = 0

    func prepare(url: URL, startTime: Double, format: AVAudioFormat) async throws {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw LocalAudioFeedError.noAudio }
        let duration = try await asset.load(.duration).seconds
        mediaDuration = duration.isFinite ? duration : .infinity
        minimumTime = startTime
        let newReader = try AVAssetReader(asset: asset)
        let bits: Int
        let isFloat: Bool
        switch format.commonFormat {
        case .pcmFormatInt16: bits = 16; isFloat = false
        case .pcmFormatInt32: bits = 32; isFloat = false
        case .pcmFormatFloat32: bits = 32; isFloat = true
        case .pcmFormatFloat64: bits = 64; isFloat = true
        default: throw LocalAudioFeedError.unsupportedFormat
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: bits,
            AVLinearPCMIsFloatKey: isFloat,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: !format.isInterleaved
        ]
        let newOutput = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: settings)
        newOutput.alwaysCopiesSampleData = false
        guard newReader.canAdd(newOutput) else { throw LocalAudioFeedError.unsupportedFormat }
        newReader.add(newOutput)
        if startTime > 0 {
            let start = CMTime(seconds: startTime, preferredTimescale: 1_000_000)
            newReader.timeRange = CMTimeRange(start: start, duration: .positiveInfinity)
        }
        guard newReader.startReading() else {
            throw LocalAudioFeedError.reader(newReader.error.map { LocalizedText(error: $0) } ?? LocalizedText("Reading could not start.", "无法开始读取"))
        }
        reader = newReader
        output = newOutput
    }

    func next(upTo playedTime: Double, playing: Bool, hasEnded: Bool) throws -> LocalPCMReadStep {
        guard let reader, let output else { return .finished }
        // Only an actual playback-end event can resolve a lagging periodic clock.
        // A user pausing close to the end must not transcribe unheard audio.
        if !playing && !hasEnded && playedTime < mediaDuration { return .waiting }
        let completed = hasEnded || playedTime >= mediaDuration
        let consumedThrough = hasEnded && mediaDuration.isFinite ? mediaDuration : min(playedTime, mediaDuration)
        if pending == nil {
            guard let sample = output.copyNextSampleBuffer() else {
                if reader.status == .failed {
                    throw LocalAudioFeedError.reader(reader.error.map { LocalizedText(error: $0) } ?? LocalizedText("Audio track reading was interrupted.", "音轨读取中断"))
                }
                if reader.status == .cancelled { throw CancellationError() }
                return .finished
            }
            pending = sample
            consumedFrames = 0
        }
        guard let sample = pending,
              let description = CMSampleBufferGetFormatDescription(sample),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description),
              let format = AVAudioFormat(streamDescription: streamDescription) else {
            throw LocalAudioFeedError.unsupportedFormat
        }
        let sampleTime = CMTimeConvertScale(CMSampleBufferGetPresentationTimeStamp(sample),
                                            timescale: CMTimeScale(format.sampleRate.rounded()), method: .roundHalfAwayFromZero)
        let timestamp = sampleTime.seconds
        guard timestamp.isFinite, format.sampleRate > 0 else { throw LocalAudioFeedError.unsupportedFormat }
        let totalFrames = CMSampleBufferGetNumSamples(sample)
        // Protect against an output buffer beginning before the requested seek time.
        let framesBeforeStart = max(0, Int(ceil((minimumTime - timestamp) * format.sampleRate)))
        consumedFrames = max(consumedFrames, min(framesBeforeStart, totalFrames))
        let currentTime = timestamp + Double(consumedFrames) / format.sampleRate
        let availableFrames = Int(floor(max(0, consumedThrough - currentTime) * format.sampleRate + 0.00001))
        let frames = min(totalFrames - consumedFrames, availableFrames, max(1, Int(format.sampleRate * 0.25)))
        if consumedFrames == totalFrames {
            pending = nil
            return .waiting
        }
        guard frames > 0 else {
            // AAC/PCM packets can contain padding beyond the asset's timeline.
            return completed && currentTime >= mediaDuration - 1 / format.sampleRate ? .finished : .waiting
        }
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else {
            throw LocalAudioFeedError.unsupportedFormat
        }
        pcm.frameLength = AVAudioFrameCount(frames)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: Int32(consumedFrames),
                                                                 frameCount: Int32(frames), into: pcm.mutableAudioBufferList)
        guard status == noErr else { throw LocalAudioFeedError.copy(status) }
        let chunkTime = CMTimeAdd(sampleTime, CMTime(value: CMTimeValue(consumedFrames),
                                                    timescale: CMTimeScale(format.sampleRate.rounded())))
        consumedFrames += frames
        if consumedFrames == totalFrames { pending = nil }
        return .buffer(.init(buffer: pcm, time: chunkTime))
    }

    func cancel() {
        reader?.cancelReading()
        reader = nil
        output = nil
        pending = nil
    }
}
