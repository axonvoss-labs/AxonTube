import AppKit
import AVFoundation
import PlayerCore
import ScreenCaptureKit

/// Uses the system's explicit application picker. No microphone or screen output is consumed.
@available(macOS 26.0, *)
@MainActor
final class PlayerAudioCapture: NSObject, SCContentSharingPickerObserver, SCStreamOutput, SCStreamDelegate {
    private(set) var isCapturing = false
    private var stream: SCStream?
    private var onBuffer: ((AVAudioPCMBuffer) async throws -> Void)?
    private var onError: ((LocalizedText) -> Void)?
    private var pump: Task<Void, Never>?
    private var selection: CheckedContinuation<SCContentFilter, Error>?
    private var input: AsyncStream<CapturedAudioPacket>.Continuation?
    private let queue = DispatchQueue(label: "io.github.axonvoss-labs.axontube.audio-capture")
    private nonisolated let inputGate = CaptureAudioInputGate(limit: 128)
    private var stopped = false
    private var reportedError = false

    func start(onBuffer: @escaping (AVAudioPCMBuffer) async throws -> Void,
               onError: @escaping (LocalizedText) -> Void) async throws {
        self.onBuffer = onBuffer
        self.onError = onError
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleApplication]
        configuration.allowsChangingSelectedContent = false
        picker.defaultConfiguration = configuration
        picker.add(self)
        picker.isActive = true
        let filter = try await withCheckedThrowingContinuation { continuation in
            selection = continuation
            picker.present()
        }
        guard !stopped else { throw CancellationError() }
        // Never broaden the user's selection to an entire display or other applications.
        let ownID = Bundle.main.bundleIdentifier ?? "io.github.axonvoss-labs.axontube"
        guard !filter.includedApplications.isEmpty,
              filter.includedApplications.allSatisfy({ $0.bundleIdentifier == ownID }) else {
            throw CaptureError.wrongApplication
        }
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.captureMicrophone = false
        config.excludesCurrentProcessAudio = false
        config.sampleRate = 16000
        config.channelCount = 1
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1)
        config.showsCursor = false
        let (buffers, continuation) = AsyncStream<CapturedAudioPacket>.makeStream(bufferingPolicy: .bufferingOldest(128))
        input = continuation
        inputGate.activate()
        pump = Task { [weak self] in
            do {
                for await packet in buffers {
                    defer { packet.permit.finish() }
                    try Task.checkCancellation()
                    guard let self, !self.stopped, self.inputGate.isCurrent(packet.generation) else { continue }
                    try await self.onBuffer?(packet.buffer)
                }
            } catch is CancellationError { }
            catch { self?.reportError(LocalizedText(error: error)) }
        }
        let capture = SCStream(filter: filter, configuration: config, delegate: self)
        try capture.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        stream = capture
        do {
            try await capture.startCapture()
            guard !stopped, !reportedError else {
                try? await capture.stopCapture()
                throw CancellationError()
            }
            isCapturing = true
        } catch {
            isCapturing = false
            inputGate.deactivate()
            throw error
        }
    }

    /// A seek/rate change invalidates captured packets already waiting in either queue.
    func discardPendingAudio() { inputGate.nextGeneration() }

    func stop() async {
        stopped = true
        isCapturing = false
        inputGate.deactivate()
        selection?.resume(throwing: CancellationError())
        selection = nil
        SCContentSharingPicker.shared.remove(self)
        SCContentSharingPicker.shared.isActive = false
        input?.finish(); input = nil
        pump?.cancel(); pump = nil
        let old = stream; stream = nil
        try? await old?.stopCapture()
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        let permit: CaptureAudioPermit
        switch inputGate.acquire() {
        case .admitted(let value): permit = value
        case .overflow(let generation):
            Task { @MainActor [weak self] in
                guard let self, self.inputGate.isCurrent(generation) else { return }
                self.reportError(LocalizedText("Audio processing cannot keep up with playback. Transcription has stopped. Close other demanding apps and try again.", "实时音频处理跟不上播放，已停止听写。请关闭其他高负载程序后重试。"))
            }
            return
        case .ignored: return
        }
        guard
              let description = sampleBuffer.formatDescription,
              let format = AVAudioFormat(cmAudioFormatDescription: description) as AVAudioFormat?,
              sampleBuffer.numSamples > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)) else { return }
        buffer.frameLength = buffer.frameCapacity
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0,
            frameCount: Int32(sampleBuffer.numSamples), into: buffer.mutableAudioBufferList) == noErr else { return }
        let packet = CapturedAudioPacket(buffer: buffer, permit: permit)
        Task { @MainActor [weak self] in
            guard let self, !self.stopped, self.inputGate.isCurrent(packet.generation), let input = self.input else { return }
            switch input.yield(packet) {
            case .enqueued: break
            case .dropped(let dropped):
                dropped.permit.finish()
                self.reportError(LocalizedText("The live audio queue is full. Close other demanding apps and try again.", "实时音频队列已满，请关闭其他高负载程序后重试。"))
            case .terminated: packet.permit.finish()
            @unknown default: packet.permit.finish()
            }
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in self?.reportError(LocalizedText(error: error)) }
    }

    private func reportError(_ message: LocalizedText) {
        guard !stopped, !reportedError else { return }
        reportedError = true
        isCapturing = false
        inputGate.deactivate()
        onError?(message)
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor [weak self] in
            self?.selection?.resume(throwing: CancellationError()); self?.selection = nil
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor [weak self] in
            self?.selection?.resume(returning: filter); self?.selection = nil
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor [weak self] in
            self?.selection?.resume(throwing: error); self?.selection = nil
        }
    }

    private enum CaptureError: BilingualError {
        case wrongApplication
        var message: LocalizedText { LocalizedText("Select AxonTube. Capture did not start because other applications' audio is excluded.", "请选择 AxonTube 应用。为避免识别其他应用的声音，本次选择没有开始采集。") }
    }
}

private struct CapturedAudioPacket: @unchecked Sendable {
    // The delegate creates independent PCM storage; neither producer mutates it after handoff.
    let buffer: AVAudioPCMBuffer
    let permit: CaptureAudioPermit
    var generation: UUID { permit.generation }
}

private enum CaptureAudioAdmission: Sendable {
    case admitted(CaptureAudioPermit), overflow(UUID), ignored
}

/// Counts storage before allocation, including MainActor tasks and the async stream.
private final class CaptureAudioInputGate: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var active = false
    private var generation = UUID()
    private var pending = 0
    private var counts: [UUID: Int] = [:]
    private var overflowReported = false

    init(limit: Int) { self.limit = limit }

    func activate() {
        lock.lock(); defer { lock.unlock() }
        active = true
        generation = UUID()
        overflowReported = false
    }

    func deactivate() {
        lock.lock(); defer { lock.unlock() }
        active = false
        generation = UUID()
    }

    func nextGeneration() {
        lock.lock(); defer { lock.unlock() }
        generation = UUID()
        overflowReported = false
    }

    func isCurrent(_ candidate: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return active && candidate == generation
    }

    func acquire() -> CaptureAudioAdmission {
        lock.lock(); defer { lock.unlock() }
        guard active else { return .ignored }
        if pending >= limit {
            // A seek can leave old-generation packets briefly draining. Drop new
            // arrival during that transition instead of reporting a stale overflow.
            if counts[generation, default: 0] >= limit && !overflowReported {
                overflowReported = true
                return .overflow(generation)
            }
            return .ignored
        }
        pending += 1
        counts[generation, default: 0] += 1
        return .admitted(CaptureAudioPermit(generation: generation, gate: self))
    }

    func release(_ generation: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard let count = counts[generation], count > 0 else { return }
        pending -= 1
        if count == 1 { counts.removeValue(forKey: generation) }
        else { counts[generation] = count - 1 }
    }
}

private final class CaptureAudioPermit: @unchecked Sendable {
    let generation: UUID
    private let gate: CaptureAudioInputGate
    private let lock = NSLock()
    private var released = false

    init(generation: UUID, gate: CaptureAudioInputGate) {
        self.generation = generation
        self.gate = gate
    }

    func finish() {
        lock.lock()
        guard !released else { lock.unlock(); return }
        released = true
        lock.unlock()
        gate.release(generation)
    }

    deinit { finish() }
}
