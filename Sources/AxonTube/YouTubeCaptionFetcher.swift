import Combine
import CryptoKit
import Darwin
import Foundation
import PlayerCore

struct YouTubeCaptionResult: Sendable {
    let videoID: String
    let primaryLanguage: String
    let secondaryLanguage: String
    let primaryURL: URL
    let secondaryURL: URL?
    let primaryCues: [SubtitleCue]
    let secondaryCues: [SubtitleCue]?
    let primaryTrack: YouTubeCaptionTrack
    let secondaryTrack: YouTubeCaptionTrack?
    let warning: LocalizedText?
    let isComplete: Bool

    var englishURL: URL { primaryURL }
    var chineseURL: URL? { secondaryURL }
    var englishCues: [SubtitleCue] { primaryCues }
    var chineseCues: [SubtitleCue]? { secondaryCues }
}

/// Network access starts only through explicit fetch/discover actions.
@MainActor
final class YouTubeCaptionFetcher: ObservableObject {
    @Published private(set) var isFetching = false
    @Published private(set) var status: LocalizedText = ""
    @Published private(set) var error: LocalizedText?
    @Published private(set) var catalog: [YouTubeCaptionTrack] = []
    @Published private(set) var catalogVideoID: String?
    @Published private(set) var languageRequestVideoID: String?
    @Published private(set) var isLoadingLanguages = false
    @Published private(set) var languageStatus: LocalizedText = ""
    @Published private(set) var languageError: LocalizedText?
    var availableTracks: [YouTubeCaptionTrack] { catalog }

    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var subprocess: CaptionSubprocess?
    private var languageTask: Task<Void, Never>?
    private var languageGeneration = UUID()
    private var languageSubprocess: CaptionSubprocess?
    private var previewMetadata: (videoID: String, data: Data)?
    private let cacheRoot: URL
    private let allowLocalFallback: Bool

    init(allowLocalFallback: Bool = true, cacheRoot: URL? = nil) {
        self.allowLocalFallback = allowLocalFallback
        self.cacheRoot = cacheRoot ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("io.github.axonvoss-labs.axontube/YouTubeCaptions/v\(YouTubeCaptionPlan.schemaVersion)", isDirectory: true)
    }

    /// The user's preview action requests metadata only. It never downloads captions
    /// or media, and a cancelled/older preview cannot publish into another video.
    func discoverLanguages(link: YouTubeLink) {
        cancel()
        clearCatalogIfNeeded(for: link.videoID)
        languageRequestVideoID = link.videoID
        let token = UUID()
        languageGeneration = token
        isLoadingLanguages = true
        languageError = nil
        languageStatus = LocalizedText("Loading available YouTube subtitle tracks…", "正在读取 YouTube 可用字幕轨道…")
        languageTask = Task { [weak self] in
            guard let self else { return }
            do {
                let executable = try helperURL()
                let runner = CaptionSubprocess()
                languageSubprocess = runner
                defer { if languageSubprocess === runner { languageSubprocess = nil } }
                let result = try await runner.run(executable: executable,
                    arguments: YouTubeCaptionPlan.metadataArguments(for: link), timeout: 45, stdoutLimit: 32 * 1_024 * 1_024)
                guard languageGeneration == token, !Task.isCancelled else { return }
                guard result.exitCode == 0 else { throw CaptionFetchError.processFailed(result.standardError) }
                guard !result.truncated else { throw CaptionFetchError.excessiveOutput }
                let tracks = try await Task.detached(priority: .utility) {
                    try YouTubeCaptionPlan.catalog(metadata: result.standardOutput, for: link)
                }.value
                guard languageGeneration == token, !Task.isCancelled else { return }
                catalog = tracks
                catalogVideoID = link.videoID
                previewMetadata = (link.videoID, result.standardOutput)
                languageStatus = tracks.isEmpty
                    ? LocalizedText("This request returned no subtitle tracks. The video may have no captions, or YouTube access may be restricted.", "本次请求未返回字幕轨道；视频可能没有字幕，或受到 YouTube 访问限制。")
                    : LocalizedText("\(tracks.count) subtitle tracks available. Choose a language and source for each track.", "共有 \(tracks.count) 条字幕轨道，可分别选择语言和来源。")
                isLoadingLanguages = false
                languageTask = nil
            } catch {
                guard languageGeneration == token, !Task.isCancelled else { return }
                languageError = LocalizedText(error: error)
                languageStatus = LocalizedText("Subtitle languages could not be loaded: ", "无法读取字幕语言：") + LocalizedText(error: error)
                isLoadingLanguages = false
                languageTask = nil
            }
        }
    }

    /// Progressively delivers the first track, followed by the second or a partial result.
    func fetch(link: YouTubeLink, primaryLanguage: String = "en", secondaryLanguage: String = "zh-Hant",
               completion: @escaping (YouTubeCaptionResult) -> Void) {
        cancel()
        clearCatalogIfNeeded(for: link.videoID)
        let token = UUID()
        generation = token
        isFetching = true
        status = LocalizedText("Checking the subtitle cache…", "正在检查字幕缓存…")
        error = nil
        task = Task { [weak self] in
            guard let self else { return }
            await self.perform(link: link, primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage,
                               token: token, completion: completion)
        }
    }

    func cancel() {
        let wasFetching = isFetching
        generation = UUID()
        task?.cancel(); task = nil
        subprocess?.cancel(); subprocess = nil
        isFetching = false
        error = nil
        status = wasFetching ? LocalizedText("Subtitle retrieval cancelled; downloaded captions are kept.", "已取消字幕获取；已下载的字幕保留。") : ""
        cancelLanguageDiscovery()
    }

    func cancelLanguageDiscovery() {
        let wasLoading = isLoadingLanguages
        languageGeneration = UUID()
        languageTask?.cancel(); languageTask = nil
        languageSubprocess?.cancel(); languageSubprocess = nil
        isLoadingLanguages = false
        languageError = nil
        if wasLoading { languageStatus = LocalizedText("Subtitle language lookup cancelled.", "已取消字幕语言查询。") }
    }

    private func clearCatalogIfNeeded(for videoID: String) {
        if catalogVideoID != videoID { catalog = []; catalogVideoID = nil; languageStatus = ""; languageError = nil }
        if previewMetadata?.videoID != videoID { previewMetadata = nil }
    }

    /// The hash keeps source-qualified choices out of filesystem paths, and includes
    /// the schema and both requested options even when the selected tracks coincide.
    static func cacheKey(primaryLanguage: String, secondaryLanguage: String) -> String {
        let key = "v\(YouTubeCaptionPlan.schemaVersion)\n\(primaryLanguage)\n\(secondaryLanguage)"
        return SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func perform(link: YouTubeLink, primaryLanguage: String, secondaryLanguage: String,
                         token: UUID, completion: @escaping (YouTubeCaptionResult) -> Void) async {
        let directory = cacheRoot.appendingPathComponent(link.videoID, isDirectory: true)
            .appendingPathComponent(Self.cacheKey(primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage), isDirectory: true)
        let primaryURL = directory.appendingPathComponent("primary.vtt")
        let secondaryURL = directory.appendingPathComponent("secondary.vtt")
        var hasPrimary = false
        var primaryCues: [SubtitleCue] = []
        var primaryDigest = ""
        var plan: YouTubeCaptionPlan?
        func result(_ plan: YouTubeCaptionPlan, second: [SubtitleCue]? = nil,
                    warning: LocalizedText? = nil, complete: Bool) -> YouTubeCaptionResult {
            .init(videoID: link.videoID, primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage,
                  primaryURL: primaryURL, secondaryURL: second == nil ? nil : secondaryURL,
                  primaryCues: primaryCues, secondaryCues: second, primaryTrack: plan.primary,
                  secondaryTrack: plan.secondary, warning: warning, isComplete: complete)
        }
        let unavailable = LocalizedText("The second-track selection (\(secondaryLanguage)) has no matching available track. The first track is kept.", "第二轨选择（\(secondaryLanguage)）没有匹配的可用字幕；第一轨已保留。")
        do {
            guard YouTubeCaptionPlan.isValidSelection(primaryLanguage), YouTubeCaptionPlan.isValidSelection(secondaryLanguage) else {
                throw YouTubeCaptionPlanError.unsafeTrack
            }
            let cached = await Task.detached(priority: .utility) {
                CaptionCache.read(directory: directory, videoID: link.videoID,
                                  primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage)
            }.value
            try check(token)
            if let cached {
                plan = cached.plan
                hasPrimary = true
                primaryCues = cached.primaryCues
                primaryDigest = cached.primaryDigest
                if let second = cached.secondaryCues {
                    finish(token: token, status: LocalizedText("Loaded both selected subtitle tracks from cache.", "已从缓存载入所选两条字幕轨道。"), warning: nil)
                    completion(result(cached.plan, second: second, complete: true))
                    return
                }
                if cached.plan.secondary == nil {
                    finish(token: token, status: unavailable, warning: unavailable)
                    completion(result(cached.plan, warning: unavailable, complete: true))
                    return
                }
                completion(result(cached.plan, complete: false))
                try check(token)
            }

            let executable = try helperURL()
            if plan == nil {
                let output: Data
                if let previewMetadata, previewMetadata.videoID == link.videoID {
                    output = previewMetadata.data
                } else {
                    status = LocalizedText("Reading YouTube's subtitle list…", "正在读取 YouTube 字幕列表…")
                    output = try await run(executable: executable, arguments: YouTubeCaptionPlan.metadataArguments(for: link),
                                           timeout: 45, stdoutLimit: 32 * 1_024 * 1_024, token: token)
                }
                let selected = try await Task.detached(priority: .utility) {
                    (try YouTubeCaptionPlan.select(metadata: output, for: link, primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage),
                     try YouTubeCaptionPlan.catalog(metadata: output, for: link))
                }.value
                try check(token)
                plan = selected.0
                catalog = selected.1
                catalogVideoID = link.videoID
                previewMetadata = (link.videoID, output)
            }
            guard let plan else { throw YouTubeCaptionPlanError.invalidMetadata }
            try check(token)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !hasPrimary {
                status = LocalizedText("Downloading the first subtitle track (\(plan.primary.languageCode))…", "正在下载第一轨字幕（\(plan.primary.languageCode)）…")
                let downloaded = try await download(plan.primary, link: link, executable: executable,
                                                     directory: directory, destination: primaryURL, token: token)
                try check(token)
                primaryCues = downloaded.cues
                primaryDigest = downloaded.digest
                hasPrimary = true
                try CaptionCache.write(plan: plan, videoID: link.videoID, directory: directory,
                                       primaryDigest: primaryDigest, secondaryDigest: nil)
                if plan.secondary != nil {
                    completion(result(plan, complete: false))
                    try check(token)
                }
            }
            guard let secondary = plan.secondary else {
                finish(token: token, status: unavailable, warning: unavailable)
                completion(result(plan, warning: unavailable, complete: true))
                return
            }

            status = secondary.isTranslation
                ? LocalizedText("The first track is ready. Fetching the second track's automatic translation may take 1–2 minutes; you can cancel…", "第一轨已就绪；正在获取第二轨自动翻译，可能需要 1–2 分钟，可取消…")
                : LocalizedText("The first track is ready. Downloading the second subtitle track…", "第一轨已就绪；正在下载第二轨字幕…")
            let downloaded = try await download(secondary, link: link, executable: executable,
                                                 directory: directory, destination: secondaryURL, token: token)
            try check(token)
            try CaptionCache.write(plan: plan, videoID: link.videoID, directory: directory,
                                   primaryDigest: primaryDigest, secondaryDigest: downloaded.digest)
            finish(token: token, status: LocalizedText("Both selected subtitle tracks are ready.", "所选两条字幕轨道已就绪。"), warning: nil)
            completion(result(plan, second: downloaded.cues, complete: true))
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            let message = LocalizedText(error: error)
            if hasPrimary, let plan {
                let warning = LocalizedText("The first subtitle track is kept; the second track did not finish: ", "第一轨字幕已保留；第二轨未完成：") + message
                finish(token: token, status: warning, warning: warning)
                completion(result(plan, warning: warning, complete: true))
            } else {
                finish(token: token, status: message, warning: message)
            }
        }
    }

    private func download(_ track: YouTubeCaptionTrack, link: YouTubeLink,
                          executable: URL, directory: URL, destination: URL, token: UUID) async throws -> (cues: [SubtitleCue], digest: String) {
        let staging = directory.appendingPathComponent("stage-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let arguments = try YouTubeCaptionPlan.downloadArguments(for: link, track: track,
                                                                 directory: staging, waitForTranslation: track.isTranslation)
        _ = try await run(executable: executable, arguments: arguments, timeout: 180,
                          stdoutLimit: 512 * 1_024, token: token)
        let source = try YouTubeCaptionPlan.downloadedFile(for: track, in: staging)
        let validated = try await Task.detached(priority: .utility) { try CaptionCache.validate(at: source) }.value
        try check(token)
        try validated.data.write(to: destination, options: .atomic)
        return (validated.cues, validated.digest)
    }

    private func run(executable: URL, arguments: [String], timeout: TimeInterval,
                     stdoutLimit: Int, token: UUID) async throws -> Data {
        try check(token)
        let runner = CaptionSubprocess()
        subprocess = runner
        defer { if subprocess === runner { subprocess = nil } }
        let result = try await runner.run(executable: executable, arguments: arguments,
                                          timeout: timeout, stdoutLimit: stdoutLimit)
        try check(token)
        guard result.exitCode == 0 else { throw CaptionFetchError.processFailed(result.standardError) }
        guard !result.truncated else { throw CaptionFetchError.excessiveOutput }
        return result.standardOutput
    }

    private func helperURL() throws -> URL {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/yt-dlp")
        let candidates = [bundled] + (allowLocalFallback ? [
            URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp"), URL(fileURLWithPath: "/usr/local/bin/yt-dlp")
        ] : [])
        guard let url = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw CaptionFetchError.missingHelper
        }
        return url
    }

    private func check(_ token: UUID) throws {
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
    }

    private func finish(token: UUID, status: LocalizedText, warning: LocalizedText?) {
        guard generation == token else { return }
        self.status = status
        error = warning
        isFetching = false
        task = nil
    }
}

private enum CaptionCache {
    private static let maximumFileSize = 32 * 1_024 * 1_024
    private struct Manifest: Codable {
        let schema: Int
        let videoID: String
        let plan: YouTubeCaptionPlan
        let primaryDigest: String
        let secondaryDigest: String?
    }
    struct Entry: Sendable {
        let plan: YouTubeCaptionPlan
        let primaryCues: [SubtitleCue]
        let secondaryCues: [SubtitleCue]?
        let primaryDigest: String
    }
    struct Validated: Sendable {
        let data: Data
        let cues: [SubtitleCue]
        let digest: String
    }

    static func read(directory: URL, videoID: String, primaryLanguage: String, secondaryLanguage: String) -> Entry? {
        let manifestURL = directory.appendingPathComponent("plan.json")
        guard let values = try? manifestURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize, size <= 16_384,
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.schema == YouTubeCaptionPlan.schemaVersion, manifest.videoID == videoID,
              manifest.plan.matches(primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage),
              let primary = try? validate(at: directory.appendingPathComponent("primary.vtt")),
              primary.digest == manifest.primaryDigest else { return nil }
        var secondaryCues: [SubtitleCue]?
        if manifest.plan.secondary != nil, let digest = manifest.secondaryDigest,
           let secondary = try? validate(at: directory.appendingPathComponent("secondary.vtt")), secondary.digest == digest {
            secondaryCues = secondary.cues
        }
        return Entry(plan: manifest.plan, primaryCues: primary.cues, secondaryCues: secondaryCues, primaryDigest: primary.digest)
    }

    static func write(plan: YouTubeCaptionPlan, videoID: String, directory: URL,
                      primaryDigest: String, secondaryDigest: String?) throws {
        let manifest = Manifest(schema: YouTubeCaptionPlan.schemaVersion, videoID: videoID, plan: plan,
                                primaryDigest: primaryDigest, secondaryDigest: secondaryDigest)
        try JSONEncoder().encode(manifest).write(to: directory.appendingPathComponent("plan.json"), options: .atomic)
    }

    static func validate(at url: URL) throws -> Validated {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= maximumFileSize else { throw CaptionFetchError.invalidSubtitle }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumFileSize, let text = String(data: data, encoding: .utf8),
              text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("WEBVTT"),
              let cues = try? SubtitleParser.parse(text, fileExtension: "vtt"), !cues.isEmpty else { throw CaptionFetchError.invalidSubtitle }
        return Validated(data: data, cues: cues, digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }
}

private enum CaptionFetchError: BilingualError {
    case missingHelper, timedOut, excessiveOutput, invalidSubtitle
    case processFailed(String)

    var message: LocalizedText {
        switch self {
        case .missingHelper: return LocalizedText("The yt-dlp subtitle helper is missing. Reinstall the complete player package.", "安装包中缺少字幕工具 yt-dlp，请重新安装完整的播放器。")
        case .timedOut: return LocalizedText("Subtitle retrieval timed out. This request was stopped.", "获取字幕超时，已停止本次请求。")
        case .excessiveOutput: return LocalizedText("The subtitle information is too large. Retrieval was stopped.", "字幕信息过大，已停止本次获取。")
        case .invalidSubtitle: return LocalizedText("The download contains no valid VTT subtitle content.", "下载结果没有有效的 VTT 字幕内容。")
        case .processFailed(let message):
            if message.contains("429") || message.localizedCaseInsensitiveContains("Too Many Requests") {
                return LocalizedText("YouTube temporarily rate-limited translated captions (429). No automatic retry was made; try again manually later.", "YouTube 暂时限制自动翻译字幕请求（429）；本次未自动重试，请稍后手动再试。")
            }
            if message.localizedCaseInsensitiveContains("Sign in") || message.localizedCaseInsensitiveContains("login") {
                return LocalizedText("YouTube requires sign-in or verification. Only directly accessible public captions are currently supported.", "YouTube 要求登录或验证，当前仅支持可直接访问的公开字幕。")
            }
            if message.contains("403") { return LocalizedText("YouTube rejected the subtitle request (403). Try again later.", "YouTube 拒绝了字幕请求（403），请稍后再试。") }
            // Do not expose signed URLs, private environment paths, or raw helper diagnostics in the UI.
            return LocalizedText("YouTube captions could not be retrieved. The video may have no available captions, or the network may be unavailable.", "YouTube 字幕获取失败，视频可能未提供可下载的字幕，或网络暂时不可用。")
        }
    }
}

/// Blocking waits and both pipe readers run off the main actor. Captured output is bounded;
/// readers keep draining after the bound to avoid a subprocess pipe deadlock.
private final class CaptionSubprocess: @unchecked Sendable {
    struct Output: Sendable {
        let exitCode: Int32
        let standardOutput: Data
        let standardError: String
        let truncated: Bool
    }
    private enum StopReason { case cancelled, timeout }
    private let lock = NSLock()
    private var process: Process?
    private var stopReason: StopReason?

    func run(executable: URL, arguments: [String], timeout: TimeInterval, stdoutLimit: Int) async throws -> Output {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    do {
                        continuation.resume(returning: try self.runBlocking(executable: executable,
                            arguments: arguments, timeout: timeout, stdoutLimit: stdoutLimit))
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { self.cancel() }
    }

    func cancel() { stop(.cancelled) }

    private func stop(_ reason: StopReason) {
        lock.lock()
        if stopReason == nil { stopReason = reason }
        let running = process
        lock.unlock()
        guard let running, running.isRunning else { return }
        running.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            if running.isRunning { _ = Darwin.kill(running.processIdentifier, SIGKILL) }
        }
    }

    private func runBlocking(executable: URL, arguments: [String], timeout: TimeInterval, stdoutLimit: Int) throws -> Output {
        let child = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        child.executableURL = executable
        child.arguments = arguments
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = stdout
        child.standardError = stderr
        // Inherit no proxy credentials, Python hooks, or unrelated environment secrets.
        child.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin",
                             "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]
        let out = CaptionPipeBuffer(limit: stdoutLimit, keepTail: false)
        let err = CaptionPipeBuffer(limit: 64 * 1_024, keepTail: true)
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
        let timeoutItem = DispatchWorkItem { [weak self] in self?.stop(.timeout) }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        child.waitUntilExit()
        timeoutItem.cancel()
        if readers.wait(timeout: .now() + 2) == .timedOut {
            // A helper descendant can inherit a pipe even after its parent exits.
            // Do not let that keep a cancelled/timed-out request alive indefinitely.
            out.requestStop()
            err.requestStop()
            readers.wait()
        }
        lock.lock()
        process = nil
        let reason = stopReason
        lock.unlock()
        if let reason {
            switch reason {
            case .cancelled: throw CancellationError()
            case .timeout: throw CaptionFetchError.timedOut
            }
        }
        return Output(exitCode: child.terminationStatus, standardOutput: out.data,
                      standardError: String(decoding: err.data, as: UTF8.self), truncated: out.truncated)
    }
}

private final class CaptionPipeBuffer: @unchecked Sendable {
    let limit: Int
    let keepTail: Bool
    private(set) var data = Data()
    private(set) var truncated = false
    private let stopLock = NSLock()
    private var stopped = false
    init(limit: Int, keepTail: Bool) { self.limit = limit; self.keepTail = keepTail }

    // One reader writes; its dispatch group is joined before the owner reads the result.
    func drain(_ handle: FileHandle) {
        defer { try? handle.close() }
        var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
        while !shouldStop {
            let ready = Darwin.poll(&descriptor, 1, 250)
            if ready < 0 {
                if errno == EINTR { continue }
                break
            }
            if ready == 0 { continue }
            guard descriptor.revents & Int16(POLLIN | POLLHUP) != 0,
                  let chunk = try? handle.read(upToCount: 32_768), !chunk.isEmpty else { break }
            if keepTail {
                data.append(chunk)
                if data.count > limit { data.removeFirst(data.count - limit); truncated = true }
            } else {
                let remaining = max(0, limit - data.count)
                data.append(chunk.prefix(remaining))
                if chunk.count > remaining { truncated = true }
            }
        }
        if shouldStop { truncated = true }
    }

    func requestStop() {
        stopLock.lock()
        stopped = true
        stopLock.unlock()
    }

    private var shouldStop: Bool {
        stopLock.lock()
        defer { stopLock.unlock() }
        return stopped
    }
}
