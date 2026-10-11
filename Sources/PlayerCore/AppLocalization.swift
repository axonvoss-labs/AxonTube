import Foundation

/// Interface language is independent of subtitle languages and the system locale.
public enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"
    case turkish = "tr"
    case vietnamese = "vi"
    case thai = "th"
    case indonesian = "id"
    case dutch = "nl"
    case polish = "pl"
    case ukrainian = "uk"
    case swedish = "sv"
    case danish = "da"
    case finnish = "fi"
    case hebrew = "he"

    /// Native names let people recover from an accidentally selected language.
    public var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .russian: "Русский"
        case .arabic: "العربية"
        case .hindi: "हिन्दी"
        case .turkish: "Türkçe"
        case .vietnamese: "Tiếng Việt"
        case .thai: "ไทย"
        case .indonesian: "Bahasa Indonesia"
        case .dutch: "Nederlands"
        case .polish: "Polski"
        case .ukrainian: "Українська"
        case .swedish: "Svenska"
        case .danish: "Dansk"
        case .finnish: "Suomi"
        case .hebrew: "עברית"
        }
    }

    public var isRightToLeft: Bool { self == .arabic || self == .hebrew }
}

public enum L10n {
    public static let preferenceKey = "interface.language"

    public static var language: AppLanguage {
        get { AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .english }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey) }
    }

    public static func text(_ english: String, _ chinese: String) -> String {
        resolve(english, chinese, for: language)
    }

    static func resolve(_ english: String, _ chinese: String, for language: AppLanguage) -> String {
        if language == .english { return english }
        if language == .simplifiedChinese { return chinese }
        if language == .traditionalChinese {
            return LocalizationCatalog.traditionalChinese(english: english, chinese: chinese)
        }
        // Unknown diagnostics remain readable in English; never translate user content.
        return LocalizationCatalog.translation(english, for: language) ?? english
    }
}

/// Store both variants for status messages so switching language does not lose state.
public struct LocalizedText: Sendable, Equatable, ExpressibleByStringLiteral {
    public let english: String
    public let chinese: String
    private let segments: [Segment]

    private struct Segment: Sendable, Equatable {
        let english: String
        let chinese: String
        let verbatim: Bool
    }

    public init(_ english: String, _ chinese: String) {
        self.english = english
        self.chinese = chinese
        self.segments = [Segment(english: english, chinese: chinese, verbatim: false)]
    }

    private init(segments: [Segment]) {
        self.segments = segments
        self.english = segments.map(\.english).joined()
        self.chinese = segments.map(\.chinese).joined()
    }

    public init(verbatim value: String) {
        self.init(segments: [Segment(english: value, chinese: value, verbatim: true)])
    }
    public init(stringLiteral value: String) { self.init(verbatim: value) }
    public init(error: Error) {
        if let bilingual = error as? BilingualError { self = bilingual.message }
        else { self.init(verbatim: error.localizedDescription) }
    }

    public func resolved(for language: AppLanguage) -> String {
        segments.map { segment in
            segment.verbatim ? segment.english : L10n.resolve(segment.english, segment.chinese, for: language)
        }.joined()
    }

    public var text: String { resolved(for: L10n.language) }
    public var isEmpty: Bool { english.isEmpty && chinese.isEmpty }

    public static func + (lhs: LocalizedText, rhs: LocalizedText) -> LocalizedText {
        LocalizedText(segments: lhs.segments + rhs.segments)
    }
}

public protocol BilingualError: LocalizedError {
    var message: LocalizedText { get }
}

public extension BilingualError {
    var errorDescription: String? { message.text }
}
