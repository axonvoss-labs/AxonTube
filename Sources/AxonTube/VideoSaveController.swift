import Combine
import Darwin
import Foundation
import PlayerCore

/// Saves start only from the user's Save Video action. Caption providers observe
/// an already running request; they never start another website caption request.
@MainActor
final class VideoSaveController: ObservableObject {
    @Published private(set) var isSaving = false
    @Published private(set) var status: LocalizedText = ""
    @Published private(set) var error: LocalizedText?
    @Published private(set) var progress: Double?
    @Published private(set) var outputDirectory: URL?

    private let helperOverride: URL?
    private var task: Task<Void, Never>?
    private var subprocess: VideoSaveSubprocess?
    private var generation = UUID()

    /// A helper override is used by deterministic offline tests. Packaged builds
    /// use their pinned helper only; arbitrary PATH installations are not used.
    init(helperURL: URL? = nil) { helperOverride = helperURL }

    func save(link: YouTubeLink, snapshot: SubtitleExportSnapshot?,
              destinationDirectory: URL, completion: @escaping (URL) -> Void) {
        save(link: link, subtitleProvider: { snapshot },
              destinationDirectory: destinationDirectory, completion: completion)
    }

    func save(link: YouTubeLink,
              subtitleProvider: @escaping @MainActor @Sendable () async -> SubtitleExportSnapshot?,
              destinationDirectory: URL, completion: @escaping (URL) -> Void) {
        begin(source: .youtube(link), subtitleProvider: subtitleProvider,
              destinationDirectory: destinationDirectory, completion: completion)
    }

    func saveLocal(mediaURL: URL, snapshot: SubtitleExportSnapshot?,
                   destinationDirectory: URL, completion: @escaping (URL) -> Void) {
        begin(source: .local(mediaURL), subtitleProvider: { snapshot },
              destinationDirectory: destinationDirectory, completion: completion)
    }

    func cancel() {
        guard isSaving else { return }
        generation = UUID()
        task?.cancel()
        subprocess?.cancel()
        task = nil
        subprocess = nil
        isSaving = false
        progress = nil
        error = nil
        status = LocalizedText("Save cancelled. Any partial files remain in the .partial folder.", "已取消保存；已生成的部分文件保留在 .partial 文件夹中。")
    }

    private enum Source: Sendable { case youtube(YouTubeLink), local(URL) }

    private func begin(source: Source,
                       subtitleProvider: @escaping @MainActor @Sendable () async -> SubtitleExportSnapshot?,
                       destinationDirectory: URL, completion: @escaping (URL) -> Void) {
        // Do not silently cancel a save if a second button action arrives.
        guard !isSaving else { return }
        let token = UUID()
        generation = token
        isSaving = true
        progress = nil
        error = nil
        outputDirectory = nil
        status = LocalizedText("Preparing video and synchronized subtitles…", "正在准备视频和同步字幕…")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let helper: URL?
                let sourceURL: URL?
                let label: String
                switch source {
                case .youtube(let link):
                    helper = try self.helperURL()
                    sourceURL = nil
                    label = link.videoID
                case .local(let mediaURL):
                    helper = nil
                    let resolved = mediaURL.standardizedFileURL.resolvingSymlinksInPath()
                    guard mediaURL.isFileURL,
                          try resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                          VideoSavePlan.videoExtensions.contains(resolved.pathExtension.lowercased()) else { throw VideoSaveError.invalidMedia }
                    sourceURL = resolved
                    label = resolved.deletingPathExtension().lastPathComponent
                }
                try self.check(token)
                let folder = try Self.createDirectory(in: destinationDirectory, label: label)
                self.outputDirectory = folder
                // Structured child work starts alongside the media transfer. On
                // cancellation or failure its bounded caption wait is cancelled too.
                async let subtitleFiles = self.saveSubtitles(using: subtitleProvider, in: folder, token: token)
                switch source {
                case .youtube(let link):
                    guard let helper else { throw VideoSaveError.missingHelper }
                    self.status = LocalizedText("Saving video…", "正在保存视频…")
                    let runner = VideoSaveSubprocess()
                    self.subprocess = runner
                    let result = try await runner.run(executable: helper, arguments: VideoSavePlan.downloadArguments(for: link),
                        directory: folder) { [weak self] value in
                            Task { @MainActor in
                                guard let self, self.generation == token, self.isSaving else { return }
                                self.progress = value
                            }
                        }
                    if self.subprocess === runner { self.subprocess = nil }
                    try self.check(token)
                    guard result.exitCode == 0 else { throw VideoSaveError.downloadFailed(result.diagnostic) }
                    let videos = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                        .filter { $0.deletingPathExtension().lastPathComponent == "video" && VideoSavePlan.videoExtensions.contains($0.pathExtension.lowercased()) }
                    guard videos.count == 1, let video = videos.first else { throw VideoSaveError.noVideo }
                    let values = try video.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else { throw VideoSaveError.noVideo }
                case .local:
                    guard let sourceURL else { throw VideoSaveError.invalidMedia }
                    self.status = LocalizedText("Copying video…", "正在复制视频…")
                    let target = folder.appendingPathComponent("video." + sourceURL.pathExtension.lowercased())
                    try await Self.work { try Self.copyFile(sourceURL, to: target) }
                    try self.check(token)
                }
                self.status = LocalizedText("Video ready. Finishing subtitles…", "视频已就绪，正在完成字幕保存…")
                let files = try await subtitleFiles
                try self.check(token)
                let finalDirectory = folder.deletingPathExtension()
                try FileManager.default.moveItem(at: folder, to: finalDirectory)
                self.outputDirectory = finalDirectory
                self.isSaving = false
                self.progress = 1
                switch source {
                case .youtube where files.isEmpty:
                    self.status = LocalizedText("Video saved. Subtitles were unavailable.", "视频已保存，字幕未能获取。")
                case .youtube where !files.contains(where: { $0.0 == "video.primary.srt" }) || !files.contains(where: { $0.0 == "video.secondary.srt" }):
                    self.status = LocalizedText("Video and available subtitles saved. One subtitle track was unavailable.", "视频和可用字幕已保存，其中一条字幕未能获取。")
                default:
                    self.status = files.isEmpty
                        ? LocalizedText("Video saved.", "视频已保存。")
                        : LocalizedText("Video and synchronized subtitles saved.", "视频和同步字幕已保存。")
                }
                self.task = nil
                completion(finalDirectory)
            } catch {
                guard self.generation == token, !Task.isCancelled else { return }
                self.subprocess = nil
                self.isSaving = false
                self.progress = nil
                let detail = LocalizedText(error: error)
                self.error = detail
                self.status = LocalizedText("Save failed:", "保存失败：") + LocalizedText(verbatim: " ") + detail
                if self.outputDirectory != nil {
                    self.status = self.status + LocalizedText(" Partial files remain in the .partial folder.", " 部分文件保留在 .partial 文件夹中。")
                }
                self.task = nil
            }
        }
    }

    private func saveSubtitles(using provider: @MainActor @Sendable () async -> SubtitleExportSnapshot?,
                               in folder: URL, token: UUID) async throws -> [(String, Data)] {
        let snapshot = await provider()
        try check(token)
        let files = try await Self.work { try Self.renderSubtitles(snapshot) }
        try check(token)
        try await Self.work {
            for (name, data) in files {
                try Task.checkCancellation()
                try data.write(to: folder.appendingPathComponent(name), options: .withoutOverwriting)
            }
        }
        return files
    }

    private func check(_ token: UUID) throws {
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
    }

    private func helperURL() throws -> URL {
        let url = helperOverride ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/yt-dlp")
        guard FileManager.default.isExecutableFile(atPath: url.path) else { throw VideoSaveError.missingHelper }
        return url
    }

    private nonisolated static func work<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        let child = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            let value = try operation()
            try Task.checkCancellation()
            return value
        }
        return try await withTaskCancellationHandler { try await child.value } onCancel: { child.cancel() }
    }

    private nonisolated static func copyFile(_ source: URL, to destination: URL) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let descriptor = Darwin.open(destination.path, O_WRONLY | O_CREAT | O_EXCL, 0o644)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let output = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? output.close() }
        while true {
            try Task.checkCancellation()
            guard let data = try input.read(upToCount: 1_048_576), !data.isEmpty else { break }
            try output.write(contentsOf: data)
        }
        try output.synchronize()
    }

    private nonisolated static func createDirectory(in parent: URL, label: String) throws -> URL {
        guard parent.isFileURL else { throw VideoSaveError.invalidDestination }
        let resolved = parent.standardizedFileURL.resolvingSymlinksInPath()
        guard try resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw VideoSaveError.invalidDestination }
        let name = "AxonTube " + VideoSavePlan.safeFolderName(label) + " " + UUID().uuidString + ".partial"
        let url = resolved.appendingPathComponent(name, isDirectory: true)
        // mkdir is exclusive: an existing destination is never silently reused.
        guard Darwin.mkdir(url.path, 0o755) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return url
    }

    private nonisolated static func renderSubtitles(_ snapshot: SubtitleExportSnapshot?) throws -> [(String, Data)] {
        guard let snapshot else { return [] }
        let empty = SubtitleTrack(cues: [])
        var files: [(String, Data)] = []
        for (name, track, offset) in [("video.primary.srt", snapshot.primary, snapshot.primaryOffset),
                                       ("video.secondary.srt", snapshot.secondary, snapshot.secondaryOffset)] where !track.cues.isEmpty {
            let output = try SubtitleExporter.srt(primary: track, secondary: empty, primaryOffset: offset)
            files.append((name, Data(output.text.utf8)))
        }
        // The combined exports deliberately do not share the media prefix, so
        // automatic adjacent-track discovery cannot pair them with a single track.
        for format in SubtitleExportFormat.allCases {
            files.append(("subtitles.bilingual." + format.rawValue, try snapshot.render(format: format).data))
        }
        return files
    }
}

private enum VideoSaveError: BilingualError {
    case missingHelper, invalidDestination, invalidMedia, noVideo, timedOut
    case downloadFailed(String)

    var message: LocalizedText {
        switch self {
        case .missingHelper: return LocalizedText("The video helper is missing. Reinstall the complete app package.", "缺少视频保存工具，请重新安装完整应用。")
        case .invalidDestination: return LocalizedText("Choose an existing local folder for the saved video.", "请选择本机现有文件夹来保存视频。")
        case .invalidMedia: return LocalizedText("The local video file is unavailable or unsupported.", "本地视频文件不可用或格式不受支持。")
        case .noVideo: return LocalizedText("The download did not produce a complete video file.", "下载未生成完整的视频文件。")
        case .timedOut: return LocalizedText("Video saving timed out. The request was stopped.", "保存视频超时，本次请求已停止。")
        case .downloadFailed(let message):
            if message.localizedCaseInsensitiveContains("Sign in") || message.localizedCaseInsensitiveContains("login") {
                return LocalizedText("YouTube requires sign-in or verification. This video cannot be saved directly.", "YouTube 要求登录或验证，无法直接保存此视频。")
            }
            if message.contains("429") || message.localizedCaseInsensitiveContains("Too Many Requests") {
                return LocalizedText("YouTube temporarily limited the download. Try again later.", "YouTube 暂时限制下载，请稍后再试。")
            }
            if message.localizedCaseInsensitiveContains("Requested format is not available") {
                return LocalizedText("This video has no directly downloadable format with both picture and sound.", "此视频没有可直接下载且同时包含画面和声音的格式。")
            }
            return LocalizedText("YouTube could not provide the video. Check the connection or try another public video.", "YouTube 未能提供视频，请检查网络或尝试其他公开视频。")
        }
    }
}

/// Only this request's owned process is stopped. Both output pipes are drained
/// off the main actor with bounded buffers; diagnostics never include raw URLs
/// or environment values in the interface.
private final class VideoSaveSubprocess: @unchecked Sendable {
    struct Output: Sendable { let exitCode: Int32; let diagnostic: String }
    private enum StopReason { case cancelled, timeout }
    private let lock = NSLock()
    private var process: Process?
    private var stopReason: StopReason?

    func run(executable: URL, arguments: [String], directory: URL,
             progress: @escaping @Sendable (Double) -> Void) async throws -> Output {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    do { continuation.resume(returning: try self.runBlocking(executable: executable, arguments: arguments, directory: directory, progress: progress)) }
                    catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { self.cancel() }
    }

    func cancel() { stop(.cancelled) }
    private func stop(_ reason: StopReason) {
        lock.lock()
        if stopReason == nil { stopReason = reason }
        let child = process
        lock.unlock()
        guard let child, child.isRunning else { return }
        child.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            if child.isRunning { _ = Darwin.kill(child.processIdentifier, SIGKILL) }
        }
    }

    private func runBlocking(executable: URL, arguments: [String], directory: URL,
                             progress: @escaping @Sendable (Double) -> Void) throws -> Output {
        let child = Process(), stdout = Pipe(), stderr = Pipe()
        child.executableURL = executable
        child.arguments = arguments
        child.currentDirectoryURL = directory
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = stdout
        child.standardError = stderr
        child.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]
        let out = VideoSavePipeBuffer(progress: progress), err = VideoSavePipeBuffer(progress: progress)
        lock.lock()
        guard stopReason == nil else { lock.unlock(); throw CancellationError() }
        process = child
        do { try child.run() }
        catch { process = nil; lock.unlock(); throw error }
        lock.unlock()
        stdout.fileHandleForWriting.closeFile()
        stderr.fileHandleForWriting.closeFile()
        let readers = DispatchGroup()
        for (pipe, buffer) in [(stdout, out), (stderr, err)] {
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                buffer.drain(pipe.fileHandleForReading)
                readers.leave()
            }
        }
        let timeout = DispatchWorkItem { [weak self] in self?.stop(.timeout) }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 21_600, execute: timeout)
        child.waitUntilExit()
        timeout.cancel()
        if readers.wait(timeout: .now() + 2) == .timedOut {
            out.requestStop(); err.requestStop()
            readers.wait()
        }
        lock.lock()
        process = nil
        let reason = stopReason
        lock.unlock()
        if let reason {
            switch reason {
            case .cancelled: throw CancellationError()
            case .timeout: throw VideoSaveError.timedOut
            }
        }
        return Output(exitCode: child.terminationStatus, diagnostic: String(decoding: err.data, as: UTF8.self))
    }
}

private final class VideoSavePipeBuffer: @unchecked Sendable {
    private(set) var data = Data()
    private let progress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var stopped = false
    init(progress: @escaping @Sendable (Double) -> Void) { self.progress = progress }

    func drain(_ handle: FileHandle) {
        defer { try? handle.close() }
        var line = Data()
        var bytes = [UInt8](repeating: 0, count: 32_768)
        var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
        while !shouldStop {
            let ready = Darwin.poll(&descriptor, 1, 250)
            if ready < 0 { if errno == EINTR { continue }; break }
            if ready == 0 { continue }
            guard descriptor.revents & Int16(POLLIN | POLLHUP) != 0 else { break }
            // A pipe read must return the bytes currently available. Foundation's
            // read(upToCount:) can wait to fill the buffer, hiding live progress
            // until the child exits and preventing timely cancellation feedback.
            let count = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
            if count < 0 { if errno == EINTR { continue }; break }
            guard count > 0 else { break }
            let chunk = Data(bytes.prefix(count))
            data.append(chunk)
            if data.count > 65_536 { data.removeFirst(data.count - 65_536) }
            for byte in chunk {
                if byte == 10 || byte == 13 {
                    if let value = VideoSavePlan.progress(in: String(decoding: line, as: UTF8.self)) { progress(value) }
                    line.removeAll(keepingCapacity: true)
                } else if line.count < 1_024 { line.append(byte) }
            }
        }
    }

    func requestStop() { lock.lock(); stopped = true; lock.unlock() }
    private var shouldStop: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}
