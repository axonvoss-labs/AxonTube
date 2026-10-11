import Foundation

/// A validated video link. Canonicalization discards tracking and unrelated query data.
public struct YouTubeLink: Equatable, Sendable {
    public let videoID: String
    public let startTime: Double

    public var canonicalURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/watch"
        components.queryItems = [URLQueryItem(name: "v", value: videoID)]
        if startTime > 0 {
            let seconds = startTime.rounded(.towardZero) == startTime
                ? String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), startTime)
                : String(startTime)
            components.queryItems?.append(URLQueryItem(name: "t", value: seconds))
        }
        // All values are generated from validated ASCII identifiers and finite numbers.
        return components.url!
    }

    private static let hosts: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
        "youtu.be", "www.youtu.be", "youtube-nocookie.com", "www.youtube-nocookie.com"
    ]
    private static let shortHosts: Set<String> = ["youtu.be", "www.youtu.be"]
    // Keep conversions to the native / JavaScript seek clock bounded (up to 365 days).
    private static let maximumStartTime = 31_536_000.0

    public static func parse(_ text: String) throws -> YouTubeLink {
        guard text.utf8.count <= 4_096 else { throw YouTubeLinkError.tooLong }
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw YouTubeLinkError.empty }
        if validVideoID(input) { return YouTubeLink(videoID: input, startTime: 0) }

        // Reject characters that URL parsers may silently repair or normalize differently.
        guard !input.unicodeScalars.contains(where: {
            CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
        }), !input.contains("\\") else { throw YouTubeLinkError.invalidURL }

        let candidate: String
        if input.contains("://") {
            candidate = input
        } else {
            let authority = input.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
            let host = authority.split(separator: ":", omittingEmptySubsequences: false).first.map(String.init)?.lowercased()
            guard let host, hosts.contains(host) else { throw YouTubeLinkError.unsupportedHost }
            candidate = "https://" + input
        }

        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host?.lowercased() else { throw YouTubeLinkError.invalidURL }
        guard components.user == nil, components.password == nil else { throw YouTubeLinkError.credentialsNotAllowed }
        guard hosts.contains(host),
              components.percentEncodedHost?.lowercased() == host else { throw YouTubeLinkError.unsupportedHost }
        if let port = components.port, port != (scheme == "https" ? 443 : 80) {
            throw YouTubeLinkError.portNotAllowed
        }
        // Encoded separators and dot segments are not standard share links.
        guard !components.percentEncodedPath.contains("%") else { throw YouTubeLinkError.unsupportedPath }
        let path = components.path.split(separator: "/", omittingEmptySubsequences: false)
        var segments = Array(path.dropFirst()).map(String.init)
        if segments.last == "" { segments.removeLast() }
        guard components.path.hasPrefix("/"), !segments.contains("") else { throw YouTubeLinkError.unsupportedPath }

        let query = components.queryItems ?? []
        let videoItems = query.filter { $0.name == "v" }
        guard videoItems.count <= 1 else { throw YouTubeLinkError.ambiguousParameters }
        let id: String
        if shortHosts.contains(host), segments.count == 1 {
            id = segments[0]
        } else if !shortHosts.contains(host), segments == ["watch"] {
            guard let value = videoItems.first?.value else { throw YouTubeLinkError.invalidVideoID }
            id = value
        } else if !shortHosts.contains(host), segments.count == 2,
                  ["shorts", "live", "embed"].contains(segments[0]) {
            id = segments[1]
        } else {
            throw YouTubeLinkError.unsupportedPath
        }
        guard validVideoID(id) else { throw YouTubeLinkError.invalidVideoID }
        if let queryID = videoItems.first?.value, queryID != id {
            throw YouTubeLinkError.ambiguousParameters
        }

        var timeItems = query.filter { $0.name == "t" || $0.name == "start" }
        // Older YouTube links use #t=1m30s. Other fragment data is discarded.
        if let fragment = components.fragment {
            var fragmentComponents = URLComponents()
            fragmentComponents.query = fragment
            timeItems += (fragmentComponents.queryItems ?? []).filter { $0.name == "t" || $0.name == "start" }
        }
        guard timeItems.count <= 1 else { throw YouTubeLinkError.ambiguousParameters }
        let start: Double
        if let timeItem = timeItems.first {
            guard let value = timeItem.value, let parsed = parseTime(value) else { throw YouTubeLinkError.invalidStartTime }
            start = parsed
        } else {
            start = 0
        }
        return YouTubeLink(videoID: id, startTime: start)
    }

    private static func validVideoID(_ value: String) -> Bool {
        value.utf8.count == 11 && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95 || $0 == 45
        }
    }

    private static func parseTime(_ value: String) -> Double? {
        guard !value.isEmpty, value.utf8.count <= 128 else { return nil }
        let seconds: Double
        if value.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) == value.startIndex..<value.endIndex {
            guard let parsed = Double(value) else { return nil }
            seconds = parsed
        } else {
            let pattern = #"^(?:([0-9]+)h)?(?:([0-9]+)m)?(?:([0-9]+(?:\.[0-9]+)?)s)?$"#
            guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  match.range == NSRange(value.startIndex..., in: value) else { return nil }
            var total = 0.0
            for (group, multiplier) in [(1, 3_600.0), (2, 60.0), (3, 1.0)] {
                if let range = Range(match.range(at: group), in: value) {
                    guard let part = Double(value[range]) else { return nil }
                    total += part * multiplier
                }
            }
            seconds = total
        }
        return seconds.isFinite && seconds >= 0 && seconds <= maximumStartTime ? seconds : nil
    }
}

public enum YouTubeLinkError: BilingualError, Equatable {
    case empty
    case tooLong
    case invalidURL
    case unsupportedHost
    case credentialsNotAllowed
    case portNotAllowed
    case unsupportedPath
    case invalidVideoID
    case ambiguousParameters
    case invalidStartTime

    public var message: LocalizedText {
        switch self {
        case .empty: return LocalizedText("Paste a YouTube video link or an 11-character video ID.", "请粘贴 YouTube 视频链接或 11 位视频 ID。")
        case .tooLong: return LocalizedText("This video link is too long. Use YouTube's share link.", "视频链接过长，请使用 YouTube 的分享链接。")
        case .invalidURL: return LocalizedText("Invalid link. Only HTTP or HTTPS YouTube video links are supported.", "链接格式不正确。只支持 HTTP 或 HTTPS 的 YouTube 视频链接。")
        case .unsupportedHost: return LocalizedText("Use an official youtube.com or youtu.be video link.", "请使用 youtube.com 或 youtu.be 的官方视频链接。")
        case .credentialsNotAllowed: return LocalizedText("Video links cannot contain a username or password. Copy YouTube's share link.", "视频链接不能包含用户名或密码。请复制 YouTube 的分享链接。")
        case .portNotAllowed: return LocalizedText("This link uses a nonstandard network port. Use YouTube's share link.", "视频链接包含非标准网络端口，请使用 YouTube 的分享链接。")
        case .unsupportedPath: return LocalizedText("No video was found. Use a watch, share, Shorts, live, or embed link.", "未识别到视频。支持 watch、分享短链接、Shorts、live 和 embed 链接。")
        case .invalidVideoID: return LocalizedText("A video ID must contain 11 letters, numbers, underscores, or hyphens.", "视频 ID 不正确，应为 11 位英文字母、数字、下划线或短横线。")
        case .ambiguousParameters: return LocalizedText("The link has duplicate or conflicting video or start-time parameters. Copy the share link again.", "链接包含重复或冲突的视频、起始时间参数，请重新复制分享链接。")
        case .invalidStartTime: return LocalizedText("Enter a nonnegative start time in seconds or a format such as 1h2m3s, no longer than 365 days.", "起始时间不正确。请输入非负秒数，或 1h2m3s 格式，最长不超过 365 天。")
        }
    }
}
