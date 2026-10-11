import Foundation
import XCTest
@testable import PlayerCore

final class YouTubeCaptionPlanTests: XCTestCase {
    private let videoID = "AbCdEf_12-3"
    private var link: YouTubeLink { try! YouTubeLink.parse(videoID) }

    private func metadata(manual: [String] = [], automatic: [String] = [], language: String? = nil,
                          id: String? = nil) throws -> Data {
        var object: [String: Any] = ["id": id ?? videoID,
            "subtitles": Dictionary(uniqueKeysWithValues: manual.map { ($0, [["ext": "vtt"]]) }),
            "automatic_captions": Dictionary(uniqueKeysWithValues: automatic.map { ($0, [["ext": "vtt"]]) })]
        if let language { object["language"] = language }
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testManualEnglishPreferredAndTranslationUsesSameSource() throws {
        let data = try metadata(manual: ["en-GB", "en-US", "en"],
                                automatic: ["en-orig", "zh-Hans", "zh-Hans-en-GB", "zh-Hans-en"])
        let plan = try YouTubeCaptionPlan.select(metadata: data, for: link)
        XCTAssertEqual(plan.english.language, "en")
        XCTAssertEqual(plan.english.kind, .manual)
        XCTAssertEqual(plan.chinese?.language, "zh-Hans-en")
        XCTAssertEqual(plan.chinese?.kind, .automatic)
    }

    func testRegionalManualPreferenceAndNoUnrelatedChineseFallback() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en-GB", "en-US"],
            automatic: ["zh-Hans", "zh-Hans-en", "zh-Hans-en-GB"]), for: link)
        XCTAssertEqual(plan.english.language, "en-US")
        XCTAssertNil(plan.chinese)
        let matching = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en-GB"],
            automatic: ["zh-Hans-en-GB"]), for: link)
        XCTAssertEqual(matching.chinese?.language, "zh-Hans-en-GB")
    }

    func testOriginalAutomaticCaptionsAndTheirChineseTranslation() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(automatic: ["en", "en-orig", "zh-Hans"]), for: link)
        XCTAssertEqual(plan.english.language, "en-orig")
        XCTAssertEqual(plan.english.kind, .automatic)
        XCTAssertEqual(plan.chinese?.language, "zh-Hans")
    }

    func testPlainAutomaticEnglishRequiresEnglishOriginalMetadata() throws {
        for language in [nil, "fr", "ja"] as [String?] {
            XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: metadata(automatic: ["en", "zh-Hans"], language: language), for: link))
        }
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(automatic: ["en-US", "zh-Hans"], language: "en-US"), for: link)
        XCTAssertEqual(plan.english.language, "en-US")
        XCTAssertEqual(plan.chinese?.language, "zh-Hans")
    }

    func testRequiresVTTAndMatchingVideoID() throws {
        let json = Data(#"{"id":"AbCdEf_12-3","subtitles":{"en":[{"ext":"json3"}]},"automatic_captions":{}}"#.utf8)
        XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: json, for: link))
        XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en"], id: "ZbCdEf_12-3"), for: link)) {
            XCTAssertEqual($0 as? YouTubeCaptionPlanError, .unexpectedVideo)
        }
        XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: Data("not json".utf8), for: link))
    }

    func testArgumentsDiscardUserParametersAndNeverReadConfigurationOrDownloadVideo() throws {
        let input = try YouTubeLink.parse("https://youtu.be/\(videoID)?si=private&list=private&t=120")
        let args = YouTubeCaptionPlan.metadataArguments(for: input)
        XCTAssertEqual(Array(args.suffix(2)), ["--", "https://www.youtube.com/watch?v=\(videoID)"])
        for required in ["--ignore-config", "--no-plugin-dirs", "--no-cache-dir", "--skip-download", "--no-playlist", "--ignore-no-formats-error", "--dump-single-json"] {
            XCTAssertTrue(args.contains(required), required)
        }
        for forbidden in ["--cookies", "--cookies-from-browser", "--netrc", "--update", "--exec", "--config-locations"] {
            XCTAssertTrue(!args.contains(forbidden), forbidden)
        }
        XCTAssertTrue(!args.joined().contains("private"))
        XCTAssertTrue(!args.joined().contains("t=120"))
    }

    func testExactSubtitleArgumentsAndTranslationDelay() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en"], automatic: ["zh-Hans-en"]), for: link)
        let directory = URL(fileURLWithPath: "/tmp/caption test $(never run); --cookies /private")
        let english = try YouTubeCaptionPlan.downloadArguments(for: link, track: plan.english, directory: directory, waitForTranslation: false)
        XCTAssertEqual(value(after: "--sub-langs", in: english), "^en$")
        XCTAssertEqual(value(after: "--paths", in: english), directory.path)
        XCTAssertTrue(english.contains("--write-subs"))
        XCTAssertTrue(english.contains("--no-write-auto-subs"))
        XCTAssertTrue(!english.contains("--sleep-subtitles"))
        let chinese = try YouTubeCaptionPlan.downloadArguments(for: link, track: XCTUnwrap(plan.chinese), directory: directory, waitForTranslation: true)
        XCTAssertEqual(value(after: "--sub-langs", in: chinese), "^zh-Hans-en$")
        XCTAssertEqual(value(after: "--sleep-subtitles", in: chinese), "65")
        XCTAssertEqual(value(after: "--retries", in: chinese), "0")
        XCTAssertTrue(chinese.contains("--write-auto-subs"))
        XCTAssertTrue(chinese.contains("--no-write-subs"))
        XCTAssertEqual(try YouTubeCaptionPlan.downloadedFile(for: plan.english, in: directory).lastPathComponent, "caption.en.vtt")
        XCTAssertThrowsError(try YouTubeCaptionPlan.downloadArguments(for: link, track: plan.english,
            directory: URL(string: "https://example.com")!, waitForTranslation: false))
    }

    func testMetadataExpandsAutomaticTranslationsWithoutWritingFilesOrListingText() {
        let arguments = YouTubeCaptionPlan.metadataArguments(for: link)
        XCTAssertTrue(arguments.contains("--write-auto-subs"))
        XCTAssertTrue(arguments.contains("--simulate"))
        XCTAssertTrue(arguments.contains("--dump-single-json"))
        XCTAssertTrue(!arguments.contains("--no-simulate"))
        XCTAssertTrue(!arguments.contains("--list-subs"))
        XCTAssertTrue(!arguments.contains("--no-write-auto-subs"))
        // Version 1 cached missing translations as a permanent absence.
        XCTAssertTrue(YouTubeCaptionPlan.schemaVersion >= 2)
    }

    func testUntrustedKeysAndCachedPlansCannotInjectOptionsOrPaths() throws {
        for value in ["en,all", "en.*", "../en", "--cookies", "en\n--exec", "en/../../escape"] {
            XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: metadata(manual: [value]), for: link))
            let object: [String: Any] = ["english": ["language": value, "kind": "manual"]]
            let data = try JSONSerialization.data(withJSONObject: object)
            XCTAssertThrowsError(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: data))
        }
        let mismatched = Data(#"{"english":{"language":"en-US","kind":"manual"},"chinese":{"language":"zh-Hans-en","kind":"automatic"}}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: mismatched))
    }

    func testCachedPlanRoundTripPreservesSelectedSource() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en-GB"], automatic: ["zh-Hans-en-GB"]), for: link)
        XCTAssertEqual(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: JSONEncoder().encode(plan)), plan)
    }

    func testGenericSelectionDefaultsSecondTrackToTraditionalChinese() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en"],
            automatic: ["zh-Hans-en", "zh-Hant-en"]), for: link, primaryLanguage: "en")
        XCTAssertEqual(plan.primary.language, "en")
        XCTAssertEqual(plan.secondary?.language, "zh-Hant-en")
        XCTAssertEqual(plan.secondary?.languageCode, "zh-Hant")
        XCTAssertEqual(plan.primaryLanguage, "en")
        XCTAssertEqual(plan.secondaryLanguage, "zh-Hant")
        XCTAssertTrue(plan.matches(primaryLanguage: "en", secondaryLanguage: "zh-Hant"))
        XCTAssertTrue(!plan.matches(primaryLanguage: "en", secondaryLanguage: "zh-Hans"))
    }

    func testGenericSelectionPrioritizesManualThenOriginalASRThenTranslation() throws {
        let all = try metadata(manual: ["fr", "en-GB"], automatic: ["en-orig", "en-fr", "zh-Hant-en-GB"])
        let manual = try YouTubeCaptionPlan.select(metadata: all, for: link, primaryLanguage: "en")
        XCTAssertEqual(manual.primary.kind, .manual)
        XCTAssertEqual(manual.primary.languageCode, "en-GB")
        let asr = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["fr"],
            automatic: ["en-orig", "en", "en-fr", "zh-Hant-en"]), for: link, primaryLanguage: "en")
        XCTAssertEqual(asr.primary.language, "en-orig")
        XCTAssertEqual(asr.primary.provenance, .originalAutomatic)
        let translated = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["fr"],
            automatic: ["en-fr", "zh-Hant-fr"]), for: link, primaryLanguage: "en")
        XCTAssertEqual(translated.primary.language, "en-fr")
        XCTAssertEqual(translated.primary.provenance, .translated)
        XCTAssertEqual(translated.primary.sourceLanguage, "fr")
        XCTAssertTrue(translated.primary.isTranslation)
        XCTAssertEqual(translated.secondary?.language, "zh-Hant-fr")
        XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: metadata(manual: ["fr"], automatic: ["en-fr"]), for: link))
    }

    func testSecondTrackPrefersSameSourceTranslationBeforeIndependentManual() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en", "fr", "zh-Hant"],
            automatic: ["zh-Hant-en", "zh-Hant-fr"]), for: link, primaryLanguage: "en")
        XCTAssertEqual(plan.secondary?.language, "zh-Hant-en")
        XCTAssertEqual(plan.secondary?.sourceLanguage, "en")
        let independent = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en", "fr", "zh-Hant"],
            automatic: ["zh-Hant-fr"]), for: link, primaryLanguage: "en")
        XCTAssertEqual(independent.secondary?.language, "zh-Hant")
        XCTAssertEqual(independent.secondary?.provenance, .manual)
        let unrelated = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en", "fr"],
            automatic: ["zh-Hant-fr"]), for: link, primaryLanguage: "en")
        XCTAssertNil(unrelated.secondary)
    }

    func testExactCatalogIDsSelectEverySourceWithoutPretendingItIsOriginal() throws {
        let data = try metadata(manual: ["en", "fr", "de"], automatic: ["en-fr", "zh-Hant-fr", "zh-Hant-en"])
        let plan = try YouTubeCaptionPlan.select(metadata: data, for: link,
            primaryLanguage: "automatic:en-fr", secondaryLanguage: "manual:de")
        XCTAssertEqual(plan.primary.id, "automatic:en-fr")
        XCTAssertEqual(plan.primary.languageCode, "en")
        XCTAssertEqual(plan.primary.provenance, .translated)
        XCTAssertEqual(plan.secondary?.id, "manual:de")
        let differentSource = try YouTubeCaptionPlan.select(metadata: data, for: link,
            primaryLanguage: "manual:en", secondaryLanguage: "automatic:zh-Hant-fr")
        XCTAssertEqual(differentSource.secondary?.sourceLanguage, "fr")
        XCTAssertEqual(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: JSONEncoder().encode(differentSource)), differentSource)
    }

    func testCatalogIncludesVTTNamesSourcesAndSeparateManualAutomaticIDs() throws {
        let data = Data(#"{"id":"AbCdEf_12-3","language":"fr","subtitles":{"en":[{"ext":"vtt","name":"English captions"}],"fr":[{"ext":"vtt","name":"Français"}],"de":[{"ext":"json3"}]},"automatic_captions":{"fr-orig":[{"ext":"vtt","name":"French (auto-generated)"}],"en":[{"ext":"vtt","name":"English"}],"zh-Hant-fr":[{"ext":"vtt","name":"Chinese (Traditional) translated from French"}],"../escape":[{"ext":"vtt"}]}}"#.utf8)
        let tracks = try YouTubeCaptionPlan.catalog(metadata: data, for: link)
        XCTAssertEqual(Set(tracks.map(\.id)), Set(["manual:en", "manual:fr", "automatic:fr-orig", "automatic:en", "automatic:zh-Hant-fr"]))
        let manual = try XCTUnwrap(tracks.first { $0.id == "manual:en" })
        XCTAssertEqual(manual.name, "English captions")
        let translated = try XCTUnwrap(tracks.first { $0.id == "automatic:zh-Hant-fr" })
        XCTAssertEqual(translated.languageCode, "zh-Hant")
        XCTAssertEqual(translated.sourceLanguage, "fr")
        XCTAssertTrue(translated.isTranslation)
        XCTAssertTrue(!translated.displayName.isEmpty)
        XCTAssertEqual(tracks.first { $0.id == "automatic:fr-orig" }?.provenance, .originalAutomatic)
        XCTAssertEqual(tracks.first { $0.id == "automatic:en" }?.provenance, .translated)
    }

    func testUnknownAutomaticSourceIsLabeledAndRequiresExactSecondSelection() throws {
        let data = try metadata(automatic: ["ar", "ja"])
        let tracks = try YouTubeCaptionPlan.catalog(metadata: data, for: link)
        XCTAssertTrue(tracks.allSatisfy { $0.provenance == .automaticUnknown && $0.sourceLanguage == nil })
        let automatic = try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: "ar", secondaryLanguage: "ja")
        XCTAssertNil(automatic.secondary)
        let exact = try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: "ar", secondaryLanguage: "automatic:ja")
        XCTAssertEqual(exact.secondary?.provenance, .automaticUnknown)
        XCTAssertEqual(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: JSONEncoder().encode(exact)), exact)
    }

    func testRegionalAndScriptOptionsKeepTraditionalAndSimplifiedSeparate() throws {
        let data = try metadata(manual: ["en-US", "en-GB", "zh-TW", "zh-CN"])
        let traditional = try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: "en", secondaryLanguage: "zh-Hant")
        XCTAssertEqual(traditional.primary.languageCode, "en-US")
        XCTAssertEqual(traditional.secondary?.languageCode, "zh-TW")
        let simplified = try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: "en", secondaryLanguage: "zh-Hans")
        XCTAssertEqual(simplified.secondary?.languageCode, "zh-CN")
        let missing = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en", "zh-Hans"]), for: link, primaryLanguage: "en")
        XCTAssertNil(missing.secondary)
    }

    func testGenericSelectionsRejectOptionAndPathInjection() throws {
        let data = try metadata(manual: ["en", "fr"], automatic: ["zh-Hant-en"])
        for selection in ["", "../en", "manual:../en", "automatic:en.*", "manual:en:fr", "other:en", "en,all", "en\n--exec", "--cookies", "en--US"] {
            XCTAssertTrue(!YouTubeCaptionPlan.isValidSelection(selection), selection)
            XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: selection))
            XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: "en", secondaryLanguage: selection))
        }
        XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: "manual:ja")) {
            XCTAssertEqual($0 as? YouTubeCaptionPlanError, .noCaptions("manual:ja"))
        }
    }

    func testGenericCacheRejectsMismatchedSelectionsSourcesAndTrackKeys() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["en"], automatic: ["zh-Hant-en"]), for: link, primaryLanguage: "en")
        let encoded = try JSONEncoder().encode(plan)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var changed = original
        changed["primaryLanguage"] = "fr"
        XCTAssertThrowsError(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: JSONSerialization.data(withJSONObject: changed)))
        changed = original
        changed["secondaryLanguage"] = "zh-Hans"
        XCTAssertThrowsError(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: JSONSerialization.data(withJSONObject: changed)))
        for (key, value) in [("language", "zh-Hant-fr"), ("languageCode", "zh-Hans"), ("sourceLanguage", "fr"), ("kind", "manual"), ("provenance", "originalAutomatic")] {
            changed = original
            var second = try XCTUnwrap(original["secondary"] as? [String: Any])
            second[key] = value
            changed["secondary"] = second
            XCTAssertThrowsError(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: JSONSerialization.data(withJSONObject: changed)), key)
        }
        XCTAssertEqual(try JSONDecoder().decode(YouTubeCaptionPlan.self, from: encoded), plan)
    }

    func testCatalogDoesNotTruncateHundredsOfSafeLanguageSourceOptions() throws {
        let targets = (0..<180).map { "lang-\($0)" }
        let data = try metadata(manual: ["en", "fr"], automatic: targets.flatMap { [$0 + "-en", $0 + "-fr"] })
        let tracks = try YouTubeCaptionPlan.catalog(metadata: data, for: link)
        XCTAssertEqual(tracks.count, 362)
        XCTAssertEqual(Set(tracks.map(\.id)).count, 362)
        let last = try YouTubeCaptionPlan.select(metadata: data, for: link,
            primaryLanguage: "automatic:lang-179-fr", secondaryLanguage: "automatic:lang-179-en")
        XCTAssertEqual(last.primary.sourceLanguage, "fr")
        XCTAssertEqual(last.secondary?.sourceLanguage, "en")
    }

    func testTranslationOnFirstTrackUsesTheSameSafeSubtitleOnlyArguments() throws {
        let plan = try YouTubeCaptionPlan.select(metadata: metadata(manual: ["fr"], automatic: ["en-fr"]), for: link, primaryLanguage: "en")
        let args = try YouTubeCaptionPlan.downloadArguments(for: link, track: plan.primary,
            directory: URL(fileURLWithPath: "/tmp/axontube-captions"), waitForTranslation: plan.primary.isTranslation)
        XCTAssertEqual(value(after: "--sub-langs", in: args), "^en-fr$")
        XCTAssertEqual(value(after: "--sleep-subtitles", in: args), "65")
        XCTAssertTrue(args.contains("--skip-download"))
        XCTAssertTrue(args.contains("--write-auto-subs"))
        XCTAssertTrue(args.contains("--no-write-subs"))
    }

    func testPartialMetadataWithNoSubtitleTablesDoesNotClaimAccessSucceeded() throws {
        let data = Data(#"{"id":"AbCdEf_12-3","title":"Known video title","language":null,"duration":null,"formats":[],"subtitles":{},"automatic_captions":{}}"#.utf8)
        let tracks = try YouTubeCaptionPlan.catalog(metadata: data, for: link)
        XCTAssertTrue(tracks.isEmpty)
        XCTAssertThrowsError(try YouTubeCaptionPlan.select(metadata: data, for: link, primaryLanguage: "en")) { error in
            XCTAssertEqual(error as? YouTubeCaptionPlanError, .noCaptions("en"))
            let guidance = (error as? BilingualError)?.message
            XCTAssertTrue(guidance?.english.contains("access may be restricted") == true)
            XCTAssertTrue(guidance?.chinese.contains("受到访问限制") == true)
        }
    }

    private func value(after option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
