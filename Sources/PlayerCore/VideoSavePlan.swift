import Foundation

/// An explicit video save uses a single complete audio/video format and never
/// loads user configuration, plugins, credentials, or automatic retry policies.
public enum VideoSavePlan {
    public static func downloadArguments(for link: YouTubeLink) -> [String] {
        ["--ignore-config", "--no-plugin-dirs", "--no-cache-dir", "--no-playlist",
         "--no-overwrites", "--no-continue", "--no-warnings", "--no-colors",
         "--retries", "0", "--fragment-retries", "0", "--extractor-retries", "0",
         "--file-access-retries", "0", "--socket-timeout", "20",
         "--abort-on-unavailable-fragments", "--no-write-subs", "--no-write-auto-subs",
         "--no-write-info-json", "--no-write-thumbnail", "--newline", "--progress",
         "--progress-template", "download:%(progress._percent_str)s",
         "--format", "best[ext=mp4]/best", "--output", "video.%(ext)s",
         "--", link.canonicalURL.absoluteString]
    }

    /// Only a display hint enters the folder name. Paths, shell metacharacters,
    /// control characters, leading dots, and overlong UTF-8 names are excluded.
    public static func safeFolderName(_ suggestedName: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:*?\"<>|%"))
        var result = ""
        for scalar in suggestedName.unicodeScalars {
            let next = forbidden.contains(scalar) ? "-" : String(scalar)
            if result.utf8.count + next.utf8.count > 100 { break }
            result += next
        }
        result = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return result.isEmpty ? "Video" : result
    }

    public static func progress(in line: String) -> Double? {
        guard line.hasPrefix("download:"), line.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("%") else { return nil }
        let value = line.dropFirst("download:".count).trimmingCharacters(in: .whitespacesAndNewlines).dropLast()
        guard let percent = Double(value), percent.isFinite, (0...100).contains(percent) else { return nil }
        return percent / 100
    }

    public static let videoExtensions: Set<String> = ["mp4", "m4v", "mov", "webm", "mkv", "avi", "mpg", "mpeg", "ts", "mts", "m2ts", "flv", "3gp"]
}
