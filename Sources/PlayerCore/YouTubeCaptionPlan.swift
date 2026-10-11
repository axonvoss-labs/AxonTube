import Foundation

/// A selectable VTT track. `language` is yt-dlp's exact key; `languageCode` is the
/// language of its text, which may differ from the language it was translated from.
public struct YouTubeCaptionTrack: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case manual, automatic }
    public enum Provenance: String, Codable, Sendable {
        case manual, originalAutomatic, translated, automaticUnknown
    }

    public let language: String
    public let kind: Kind
    public let languageCode: String
    public let name: String
    public let sourceLanguage: String?
    public let provenance: Provenance
    public var id: String { kind.rawValue + ":" + language }
    public var isTranslation: Bool { provenance == .translated }

    public var displayName: String {
        let locale = Locale(identifier: L10n.language.rawValue)
        func title(_ code: String) -> String { locale.localizedString(forIdentifier: code) ?? code }
        let detail: String
        switch provenance {
        case .manual: detail = L10n.text("Manual captions", "人工字幕")
        case .originalAutomatic: detail = L10n.text("Original ASR", "原语自动识别")
        case .translated:
            let source = sourceLanguage.map(title) ?? L10n.text("unknown source", "未知源语")
            detail = L10n.text("Auto-translated from \(source)", "自动翻译自\(source)")
        case .automaticUnknown: detail = L10n.text("Automatic · source unknown", "自动字幕 · 源语未知")
        }
        return "\(title(languageCode)) · \(detail) [\(language)]"
    }

    fileprivate var sourceForTranslation: String? {
        switch provenance {
        case .manual, .originalAutomatic: return languageCode
        case .translated: return sourceLanguage
        case .automaticUnknown: return nil
        }
    }

    fileprivate var isValid: Bool {
        guard YouTubeCaptionPlan.safeLanguage(language), YouTubeCaptionPlan.safeLanguage(languageCode),
              name.utf8.count <= 1_024,
              sourceLanguage.map(YouTubeCaptionPlan.safeLanguage) ?? true else { return false }
        switch provenance {
        case .manual:
            return kind == .manual && language == languageCode && sourceLanguage == languageCode
        case .originalAutomatic:
            return kind == .automatic && sourceLanguage == languageCode
                && (language == languageCode || language == languageCode + "-orig")
        case .translated:
            guard let sourceLanguage else { return false }
            return kind == .automatic && (language == languageCode || language == languageCode + "-" + sourceLanguage)
        case .automaticUnknown:
            return kind == .automatic && sourceLanguage == nil && language == languageCode && !language.hasSuffix("-orig")
        }
    }
}

/// Safe, explicit selection of two subtitle tracks. Only user-selected caption
/// metadata and text are requested; no media, credentials, or helper config is used.
public struct YouTubeCaptionPlan: Codable, Equatable, Sendable {
    public static let schemaVersion = 3
    public let primary: YouTubeCaptionTrack
    public let secondary: YouTubeCaptionTrack?
    /// Request values are plain language codes or exact catalog IDs such as `manual:en`.
    public let primaryLanguage: String
    public let secondaryLanguage: String
    private let legacyOriginalOnly: Bool

    // Compatibility for existing callers; the generic API never labels these original/translated.
    public var english: YouTubeCaptionTrack { primary }
    public var chinese: YouTubeCaptionTrack? { secondary }

    private static let englishLanguages = ["en", "en-US", "en-GB", "en-AU", "en-CA", "en-NZ", "en-IE", "en-IN", "en-ZA", "en-SG", "en-HK"]
    private static let commonArguments = [
        "--ignore-config", "--no-plugin-dirs", "--no-cache-dir", "--no-playlist",
        "--skip-download", "--ignore-no-formats-error", "--no-warnings", "--no-progress", "--no-colors",
        "--retries", "0", "--extractor-retries", "0", "--file-access-retries", "0", "--socket-timeout", "15"
    ]

    private init(primary: YouTubeCaptionTrack, secondary: YouTubeCaptionTrack?,
                 primaryLanguage: String, secondaryLanguage: String, legacyOriginalOnly: Bool = false) {
        self.primary = primary
        self.secondary = secondary
        self.primaryLanguage = primaryLanguage
        self.secondaryLanguage = secondaryLanguage
        self.legacyOriginalOnly = legacyOriginalOnly
    }

    /// Retains the former strict English / Simplified Chinese behavior for older callers.
    /// New callers pass their explicit options to the generic overload below.
    public static func select(metadata data: Data, for link: YouTubeLink) throws -> YouTubeCaptionPlan {
        let metadata = try readMetadata(data, for: link)
        let tracks = makeCatalog(metadata)
        func track(_ key: String, _ kind: YouTubeCaptionTrack.Kind) -> YouTubeCaptionTrack? {
            tracks.first { $0.language == key && $0.kind == kind }
        }
        let primary: YouTubeCaptionTrack
        if let manual = englishLanguages.compactMap({ track($0, .manual) }).first {
            primary = manual
        } else if let original = englishLanguages.compactMap({ track($0 + "-orig", .automatic) }).first {
            primary = original
        } else if let originalLanguage = metadata.language, englishLanguages.contains(originalLanguage),
                  let original = track(originalLanguage, .automatic), original.provenance == .originalAutomatic {
            primary = original
        } else { throw YouTubeCaptionPlanError.noOriginalEnglish }
        let keys = primary.kind == .manual
            ? ["zh-Hans-" + primary.languageCode]
            : ["zh-Hans", "zh-Hans-" + primary.languageCode]
        let secondary = keys.compactMap { track($0, .automatic) }.first {
            $0.provenance == .translated && $0.sourceLanguage == primary.languageCode
        }
        return .init(primary: primary, secondary: secondary, primaryLanguage: "en", secondaryLanguage: "zh-Hans", legacyOriginalOnly: true)
    }

    /// A plain code chooses manual captions, then original ASR, then a translation.
    /// An exact catalog ID selects that precise source. The default app request is
    /// English first and Traditional Chinese second, supplied explicitly by the model.
    public static func select(metadata data: Data, for link: YouTubeLink,
                              primaryLanguage: String, secondaryLanguage: String = "zh-Hant") throws -> YouTubeCaptionPlan {
        guard isValidSelection(primaryLanguage), isValidSelection(secondaryLanguage) else {
            throw YouTubeCaptionPlanError.unsafeTrack
        }
        let tracks = try catalog(metadata: data, for: link)
        let first = candidates(for: primaryLanguage, in: tracks)
        guard let primary = first.first else { throw YouTubeCaptionPlanError.noCaptions(primaryLanguage) }
        let choices = candidates(for: secondaryLanguage, in: tracks)
        let secondary: YouTubeCaptionTrack?
        if exactSelection(secondaryLanguage) != nil {
            // Explicit source selection may intentionally choose an independent track.
            secondary = choices.first
        } else {
            secondary = choices.first { $0.isTranslation && $0.sourceLanguage == primary.sourceForTranslation && $0.sourceLanguage != nil }
                ?? choices.first { $0.kind == .manual }
                ?? choices.first { $0.provenance == .originalAutomatic }
            // Do not silently substitute an unrelated translation for a language-only request.
        }
        return .init(primary: primary, secondary: secondary,
                     primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage)
    }

    /// Lists every safe VTT manual/automatic track, including source-language variants.
    /// It parses supplied metadata only and never initiates network access.
    public static func catalog(metadata data: Data, for link: YouTubeLink) throws -> [YouTubeCaptionTrack] {
        makeCatalog(try readMetadata(data, for: link))
    }

    public static func isValidSelection(_ value: String) -> Bool {
        if let exact = exactSelection(value) { return safeLanguage(exact.language) }
        return safeLanguage(value)
    }

    public func matches(primaryLanguage: String, secondaryLanguage: String) -> Bool {
        self.primaryLanguage == primaryLanguage && self.secondaryLanguage == secondaryLanguage
    }

    private static func exactSelection(_ value: String) -> (kind: YouTubeCaptionTrack.Kind, language: String)? {
        let components = value.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 2, let kind = YouTubeCaptionTrack.Kind(rawValue: String(components[0])),
              safeLanguage(String(components[1])) else { return nil }
        return (kind, String(components[1]))
    }

    private static func candidates(for selection: String, in tracks: [YouTubeCaptionTrack]) -> [YouTubeCaptionTrack] {
        if let exact = exactSelection(selection) {
            return tracks.filter { $0.kind == exact.kind && $0.language == exact.language }
        }
        return tracks.filter { languageRank($0.languageCode, requested: selection) != nil }.sorted { a, b in
            let pa = provenanceRank(a.provenance), pb = provenanceRank(b.provenance)
            if pa != pb { return pa < pb }
            let la = languageRank(a.languageCode, requested: selection)!, lb = languageRank(b.languageCode, requested: selection)!
            if la != lb { return la < lb }
            if a.provenance == .originalAutomatic && a.language.hasSuffix("-orig") != b.language.hasSuffix("-orig") {
                return a.language.hasSuffix("-orig")
            }
            return a.id < b.id
        }
    }

    private static func provenanceRank(_ provenance: YouTubeCaptionTrack.Provenance) -> Int {
        switch provenance {
        case .manual: return 0
        case .originalAutomatic: return 1
        case .translated: return 2
        case .automaticUnknown: return 3
        }
    }

    private static func languageRank(_ candidate: String, requested: String) -> Int? {
        if candidate.caseInsensitiveCompare(requested) == .orderedSame { return 0 }
        let wanted = requested.lowercased(), code = candidate.lowercased()
        if wanted == "en", let index = englishLanguages.firstIndex(where: { $0.lowercased() == code }) { return index + 1 }
        if wanted == "zh-hant", ["zh-tw", "zh-hk", "zh-mo"].contains(code) { return 1 }
        if wanted == "zh-hans", ["zh-cn", "zh-sg"].contains(code) { return 1 }
        if !wanted.contains("-"), code.hasPrefix(wanted + "-") { return 100 }
        return nil
    }

    private static func readMetadata(_ data: Data, for link: YouTubeLink) throws -> Metadata {
        guard data.count <= 32 * 1_024 * 1_024 else { throw YouTubeCaptionPlanError.invalidMetadata }
        let metadata: Metadata
        do { metadata = try JSONDecoder().decode(Metadata.self, from: data) }
        catch { throw YouTubeCaptionPlanError.invalidMetadata }
        guard metadata.id == link.videoID else { throw YouTubeCaptionPlanError.unexpectedVideo }
        return metadata
    }

    private static func makeCatalog(_ metadata: Metadata) -> [YouTubeCaptionTrack] {
        let manual = metadata.subtitles ?? [:]
        let automatic = metadata.automaticCaptions ?? [:]
        func validKeys(_ table: [String: [Format]]) -> [String] {
            table.keys.filter { safeLanguage($0) && table[$0]?.contains { $0.ext == "vtt" } == true }
        }
        let manualKeys = validKeys(manual)
        let autoKeys = validKeys(automatic)
        let originals = autoKeys.filter { $0.hasSuffix("-orig") }.map { String($0.dropLast(5)) }.filter(safeLanguage)
        let declaredSource = metadata.language.flatMap { safeLanguage($0) ? $0 : nil }
        let defaultSource = declaredSource ?? (Set(originals).count == 1 ? originals.first : nil)
        let sources = Set(manualKeys + originals + [declaredSource].compactMap { $0 }).sorted {
            $0.count == $1.count ? $0 < $1 : $0.count > $1.count
        }
        func name(_ key: String, table: [String: [Format]]) -> String {
            let raw = table[key]?.first(where: { $0.ext == "vtt" })?.name ?? key
            let cleaned = raw.components(separatedBy: .controlCharacters).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.utf8.count <= 1_024 && !cleaned.isEmpty ? cleaned : key
        }
        var tracks = manualKeys.map {
            YouTubeCaptionTrack(language: $0, kind: .manual, languageCode: $0, name: name($0, table: manual), sourceLanguage: $0, provenance: .manual)
        }
        for key in autoKeys {
            let language: String
            let source: String?
            let provenance: YouTubeCaptionTrack.Provenance
            if key.hasSuffix("-orig"), safeLanguage(String(key.dropLast(5))) {
                language = String(key.dropLast(5)); source = language; provenance = .originalAutomatic
            } else if let suffix = sources.first(where: { key.hasSuffix("-" + $0) && safeLanguage(String(key.dropLast($0.count + 1))) }) {
                language = String(key.dropLast(suffix.count + 1)); source = suffix; provenance = .translated
            } else if key == declaredSource || originals.contains(key) {
                language = key; source = key; provenance = .originalAutomatic
            } else if let defaultSource {
                language = key; source = defaultSource; provenance = .translated
            } else {
                language = key; source = nil; provenance = .automaticUnknown
            }
            let track = YouTubeCaptionTrack(language: key, kind: .automatic, languageCode: language,
                                            name: name(key, table: automatic), sourceLanguage: source, provenance: provenance)
            if track.isValid { tracks.append(track) }
        }
        return tracks.sorted {
            if $0.languageCode != $1.languageCode { return $0.languageCode < $1.languageCode }
            let a = provenanceRank($0.provenance), b = provenanceRank($1.provenance)
            return a == b ? $0.id < $1.id : a < b
        }
    }

    /// Deliberately drops playback position, playlist and tracking parameters.
    public static func watchURL(for link: YouTubeLink) -> URL {
        URL(string: "https://www.youtube.com/watch?v=\(link.videoID)")!
    }

    public static func metadataArguments(for link: YouTubeLink) -> [String] {
        commonArguments + ["--write-auto-subs", "--simulate", "--dump-single-json", "--", watchURL(for: link).absoluteString]
    }

    public static func downloadArguments(for link: YouTubeLink, track: YouTubeCaptionTrack,
                                         directory: URL, waitForTranslation: Bool) throws -> [String] {
        guard directory.isFileURL else { throw YouTubeCaptionPlanError.invalidDestination }
        guard track.isValid else { throw YouTubeCaptionPlanError.unsafeTrack }
        var arguments = commonArguments + [
            "--no-simulate",
            track.kind == .manual ? "--write-subs" : "--no-write-subs",
            track.kind == .automatic ? "--write-auto-subs" : "--no-write-auto-subs",
            "--sub-format", "vtt", "--sub-langs", "^" + NSRegularExpression.escapedPattern(for: track.language) + "$",
            "--paths", directory.path, "--output", "caption.%(ext)s"
        ]
        if waitForTranslation { arguments += ["--sleep-subtitles", "65"] }
        return arguments + ["--", watchURL(for: link).absoluteString]
    }

    public static func downloadedFile(for track: YouTubeCaptionTrack, in directory: URL) throws -> URL {
        guard directory.isFileURL else { throw YouTubeCaptionPlanError.invalidDestination }
        guard track.isValid else { throw YouTubeCaptionPlanError.unsafeTrack }
        return directory.appendingPathComponent("caption.\(track.language).vtt", isDirectory: false)
    }

    fileprivate static func safeLanguage(_ value: String) -> Bool {
        value.utf8.count <= 64 && !value.isEmpty && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45
        } && value.first?.isLetter == true && !value.split(separator: "-", omittingEmptySubsequences: false).contains("")
    }

    // A cached plan must agree with both user options and its exact source identities.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let primary = try container.decode(YouTubeCaptionTrack.self, forKey: .primary)
        let secondary = try container.decodeIfPresent(YouTubeCaptionTrack.self, forKey: .secondary)
        let first = try container.decode(String.self, forKey: .primaryLanguage)
        let second = try container.decode(String.self, forKey: .secondaryLanguage)
        let legacy = try container.decode(Bool.self, forKey: .legacyOriginalOnly)
        guard Self.isValidSelection(first), Self.isValidSelection(second), primary.isValid,
              Self.candidates(for: first, in: [primary]).count == 1 else { throw YouTubeCaptionPlanError.unsafeTrack }
        if let secondary {
            guard secondary.isValid, Self.candidates(for: second, in: [secondary]).count == 1 else {
                throw YouTubeCaptionPlanError.unsafeTrack
            }
            if Self.exactSelection(second) == nil {
                if secondary.provenance == .automaticUnknown { throw YouTubeCaptionPlanError.unsafeTrack }
                if secondary.isTranslation, secondary.sourceLanguage != primary.sourceForTranslation {
                    throw YouTubeCaptionPlanError.unsafeTrack
                }
            }
        }
        if legacy {
            guard first == "en", second == "zh-Hans", Self.englishLanguages.contains(primary.languageCode),
                  primary.provenance == .manual || primary.provenance == .originalAutomatic else {
                throw YouTubeCaptionPlanError.unsafeTrack
            }
            if let secondary {
                guard secondary.isTranslation, secondary.sourceLanguage == primary.languageCode else { throw YouTubeCaptionPlanError.unsafeTrack }
                if primary.kind == .manual, secondary.language != "zh-Hans-" + primary.languageCode {
                    throw YouTubeCaptionPlanError.unsafeTrack
                }
            }
        }
        self.init(primary: primary, secondary: secondary, primaryLanguage: first, secondaryLanguage: second, legacyOriginalOnly: legacy)
    }

    private enum CodingKeys: String, CodingKey { case primary, secondary, primaryLanguage, secondaryLanguage, legacyOriginalOnly }
    private struct Format: Decodable { let ext: String?; let name: String? }
    private struct Metadata: Decodable {
        let id: String
        let language: String?
        let subtitles: [String: [Format]]?
        let automaticCaptions: [String: [Format]]?
        enum CodingKeys: String, CodingKey {
            case id, language, subtitles
            case automaticCaptions = "automatic_captions"
        }
    }
}

public enum YouTubeCaptionPlanError: BilingualError, Equatable {
    case invalidMetadata, unexpectedVideo, noOriginalEnglish, invalidDestination, unsafeTrack
    case noCaptions(String)

    public var message: LocalizedText {
        switch self {
        case .invalidMetadata: return LocalizedText("YouTube's subtitle information could not be read.", "YouTube 返回的字幕信息无法读取。")
        case .unexpectedVideo: return LocalizedText("YouTube returned a different video. Subtitle retrieval was cancelled.", "YouTube 返回的视频与当前视频不一致，已取消字幕获取。")
        case .noOriginalEnglish: return LocalizedText("This video has no available original English captions. Translations into English are not used as the original track.", "这段视频没有可获取的英文原文字幕；仅提供翻译成英文的字幕时不会冒充原文。")
        case .noCaptions(let language): return LocalizedText("YouTube returned no captions matching the first-track selection (\(language)). Matching captions may be absent, or access may be restricted.", "本次请求未返回符合第一轨选择（\(language)）的字幕；可能没有相应字幕，或受到访问限制。")
        case .invalidDestination: return LocalizedText("The subtitle cache folder is unavailable.", "字幕缓存目录不可用。")
        case .unsafeTrack: return LocalizedText("The subtitle track information is invalid. Retrieval was stopped.", "字幕轨道信息无效，已停止获取。")
        }
    }
}
