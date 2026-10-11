import Foundation
import PlayerCore

/// Each option comes from the corresponding Apple framework's supported list.
struct SpeechLanguageOption: Identifiable, Hashable, Sendable {
    let identifier: String
    var id: String { identifier }
    var name: String { Self.name(for: identifier, locale: L10n.language.rawValue) }
    var bilingualName: LocalizedText {
        LocalizedText(Self.name(for: identifier, locale: "en"), Self.name(for: identifier, locale: "zh-Hans"))
    }

    static func name(for identifier: String, locale: String) -> String {
        let language = Locale.Language(identifier: identifier)
        // Foundation minimizes zh-Hant to zh-TW. Keep the script visible in language menus.
        let displayIdentifier = language.languageCode?.identifier == "zh" ? language.maximalIdentifier : identifier
        return Locale(identifier: locale).localizedString(forIdentifier: displayIdentifier) ?? identifier
    }
}

enum SpeechLanguageSettings {
    static let sourcePreferenceKey = "liveCaption.sourceLocaleIdentifier"
    static let targetPreferenceKey = "liveCaption.targetLanguageIdentifier"
    static let defaultSourceIdentifier = "en-US"
    static let defaultTargetIdentifier = "zh-Hant"

    static func canonicalIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    static func options(identifiers: [String]) -> [SpeechLanguageOption] {
        var seen: Set<String> = []
        return identifiers.sorted().compactMap { identifier in
            guard seen.insert(canonicalIdentifier(identifier)).inserted else { return nil }
            return SpeechLanguageOption(identifier: identifier)
        }
    }

    static func exactMatch(_ identifier: String, in options: [SpeechLanguageOption]) -> SpeechLanguageOption? {
        options.first { canonicalIdentifier($0.identifier) == canonicalIdentifier(identifier) }
    }

    /// Script identity is required: Traditional Chinese must never become Simplified Chinese.
    static func languageMatch(_ identifier: String, in options: [SpeechLanguageOption]) -> SpeechLanguageOption? {
        if let exact = exactMatch(identifier, in: options) { return exact }
        let requested = Locale.Language(identifier: identifier)
        return options.first {
            let candidate = Locale.Language(identifier: $0.identifier)
            return candidate.languageCode == requested.languageCode && candidate.script == requested.script
        }
    }

    static func defaultSpeech(in options: [SpeechLanguageOption]) -> SpeechLanguageOption? {
        languageMatch(defaultSourceIdentifier, in: options)
    }

    static func defaultTranslation(in options: [SpeechLanguageOption]) -> SpeechLanguageOption? {
        languageMatch(defaultTargetIdentifier, in: options)
    }
}
