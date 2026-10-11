#!/usr/bin/env python3
"""Offline PlayerModel integration checks, isolated from SwiftPM and real preferences.

Compiles the actual application sources except its GUI entry point. A unique temporary
bundle supplies a separate UserDefaults domain; no media, web views or models start.
"""
import hashlib
import pathlib
import platform
import plistlib
import subprocess
import tempfile
import uuid

root = pathlib.Path(__file__).resolve().parents[1]
work = pathlib.Path(tempfile.mkdtemp(prefix="axontube-model-check-"))
bundle_id = "io.github.axonvoss-labs.axontube.integration." + uuid.uuid4().hex
app = work / "ModelChecks.app"
frameworks = app / "Contents/Frameworks"
executable = app / "Contents/MacOS/ModelChecks"
modules = work / "Modules"
for directory in (frameworks, executable.parent, modules):
    directory.mkdir(parents=True, exist_ok=True)
(app / "Contents/Info.plist").write_bytes(plistlib.dumps({
    "CFBundleIdentifier": bundle_id, "CFBundleExecutable": "ModelChecks",
    "CFBundleName": "Player Model Integration Checks", "CFBundlePackageType": "APPL",
    "LSUIElement": True,
}))

harness = r'''
import AppKit
import CryptoKit
import Foundation
import PlayerCore

@MainActor
enum AppDelegate {
    static var openFiles: (([URL]) -> Void)?
    static var pendingURLs: [URL] = []
    static var willExit: (() -> Void)?
}

struct CheckFailure: Error, CustomStringConvertible { let description: String }

@main
@MainActor
struct ModelIntegrationChecks {
    static var assertions = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        assertions += 1
        if !condition() { throw CheckFailure(description: message) }
    }
    static func expectFailure(_ message: String, _ operation: () throws -> Void) throws {
        assertions += 1
        do { try operation() } catch { return }
        throw CheckFailure(description: message)
    }
    static func cue(_ id: Int, _ start: Double, _ end: Double, _ text: String) -> SubtitleCue {
        SubtitleCue(id: id, start: start, end: end, text: text)
    }
    static func settled(_ model: PlayerModel) async throws {
        let deadline = Date().addingTimeInterval(8)
        while model.sentencesBuilding && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        try expect(!model.sentencesBuilding, "sentence rebuild did not settle")
    }
    // Await the actual superseded work instead of guessing a sleep long enough for it.
    // Reflection only observes task handles; production code is compiled unchanged.
    static func task<T>(_ label: String, in model: PlayerModel, as: T.Type) -> T? {
        guard let value = Mirror(reflecting: model).children.first(where: { $0.label == label })?.value else { return nil }
        if let direct = value as? T { return direct }
        return Mirror(reflecting: value).children.first?.value as? T
    }
    static func startedWorker(_ model: PlayerModel) async throws -> Task<SubtitleSentenceBuilder.Result, Never> {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let worker = task("sentenceWorker", in: model, as: Task<SubtitleSentenceBuilder.Result, Never>.self) { return worker }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw CheckFailure(description: "background sentence worker was not observable")
    }

    static func settleCaptions(_ model: PlayerModel) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let selection = task("captionSelectionTask", in: model, as: Task<Void, Never>.self)
            if selection == nil && !model.youtubeCaptions.isFetching { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw CheckFailure(description: "automatic caption request did not settle")
    }

    static func captionFixture(root: URL, link: YouTubeLink, primary: String, secondary: String,
                               firstText: String, secondText: String?) throws {
        let metadata: [String: Any] = ["id": link.videoID, "subtitles": [primary: [["ext": "vtt"]]],
            "automatic_captions": [secondary + "-" + primary: [["ext": "vtt"]]]]
        let plan = try YouTubeCaptionPlan.select(metadata: JSONSerialization.data(withJSONObject: metadata),
            for: link, primaryLanguage: primary, secondaryLanguage: secondary)
        let key = YouTubeCaptionFetcher.cacheKey(primaryLanguage: primary, secondaryLanguage: secondary)
        let directory = root.appendingPathComponent(link.videoID).appendingPathComponent(key)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func bytes(_ text: String) -> Data { Data("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n\(text)\n".utf8) }
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        let first = bytes(firstText)
        try first.write(to: directory.appendingPathComponent("primary.vtt"))
        var manifest: [String: Any] = ["schema": YouTubeCaptionPlan.schemaVersion, "videoID": link.videoID,
            "plan": try JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)), "primaryDigest": digest(first)]
        if let secondText {
            let second = bytes(secondText)
            try second.write(to: directory.appendingPathComponent("secondary.vtt"))
            manifest["secondaryDigest"] = digest(second)
        }
        try JSONSerialization.data(withJSONObject: manifest).write(to: directory.appendingPathComponent("plan.json"))
    }

    static func checkAutomaticYouTubeCaptions(directory: URL) async throws {
        let root = directory.appendingPathComponent("workflow-caption-cache")
        let link = try YouTubeLink.parse("AbCdEf_12-3")
        let other = try YouTubeLink.parse("ZbCdEf_12-3")
        try captionFixture(root: root, link: link, primary: "en", secondary: "zh-Hant", firstText: "English first.", secondText: "繁體中文。")
        try captionFixture(root: root, link: link, primary: "ja", secondary: "fr", firstText: "日本語。", secondText: "Français.")
        try captionFixture(root: root, link: link, primary: "en", secondary: "de", firstText: "English refresh.", secondText: nil)
        try captionFixture(root: root, link: other, primary: "en", secondary: "zh-Hant", firstText: "Other video.", secondText: "另一影片。")
        let fetcher = YouTubeCaptionFetcher(allowLocalFallback: false, cacheRoot: root)
        let model = PlayerModel(youtubeCaptions: fetcher)
        try expect(!model.canSaveVideo, "empty player enabled Save Video")
        // Constructing the controller does not load WKWebView or start a network request.
        model.youtube = YouTubeController(link: link)
        try expect(model.canSaveVideo && model.makeVideoSubtitleSnapshot() == nil,
                   "an opened YouTube video with no captions could not be saved")
        model.primaryCaptionLanguage = "en"
        model.secondaryCaptionLanguage = "zh-Hant"
        model.sentenceMode = true
        model.beginYouTubeSubtitleSession(link)
        try expect(fetcher.isFetching, "opening a subtitle session did not fetch automatically")
        try expect(model.canSaveVideo && model.isPreparingYouTubeCaptions,
                   "an in-flight initial caption request disabled Save Video")
        let initialSave = model.makeVideoSubtitleSaveProvider()
        let request = Mirror(reflecting: model).children.first { $0.label == "captionRequestGeneration" }?.value as? UUID
        model.beginYouTubeSubtitleSession(link)
        let retained = Mirror(reflecting: model).children.first { $0.label == "captionRequestGeneration" }?.value as? UUID
        try expect(request != nil && request == retained, "same-video reload restarted the in-flight caption request")
        try await settleCaptions(model)
        let initialSavedCaptions = await initialSave()
        try expect(initialSavedCaptions?.primary.cues.first?.text == "English first."
                   && initialSavedCaptions?.secondary.cues.first?.text == "繁體中文。",
                   "save made during retrieval did not pick up both completed tracks")
        try expect(model.slots[0].track.cues.first?.text == "English first." && model.slots[1].track.cues.first?.text == "繁體中文。",
                   "default session did not install both cached language tracks")
        model.slots[0].offset = 1.25
        model.slots[1].offset = -0.25
        let snapshot = model.makeVideoSubtitleSnapshot()
        try expect(snapshot?.primary.cues.first?.start == 1 && snapshot?.primaryOffset == 1.25
                   && snapshot?.secondaryOffset == -0.25, "video save lost raw cue times or independent timing corrections")
        model.beginYouTubeSubtitleSession(link)
        try expect(!fetcher.isFetching && model.slots[0].offset == 1.25 && model.slots[1].offset == -0.25,
                   "same-video reload cleared or downloaded already loaded subtitles")
        model.currentTime = 42
        model.speed = 0.75
        model.primaryCaptionLanguage = "ja"
        model.secondaryCaptionLanguage = "fr"
        try expect(model.slots[1].track.cues.first?.text == "繁體中文。", "changing a picker immediately discarded usable subtitles")
        try expect(model.canSaveVideo && model.isPreparingYouTubeCaptions,
                   "language selection debounce disabled Save Video")
        let changedPairSave = model.makeVideoSubtitleSaveProvider()
        let boundedSave = model.makeVideoSubtitleSaveProvider(timeout: .zero)
        let boundedSnapshot = await boundedSave()
        try expect(boundedSnapshot == nil, "expired save wait used stale captions from a different selected pair")
        model.slots[0].offset = 8
        model.slots[1].offset = 9
        try await settleCaptions(model)
        let changedPairSavedCaptions = await changedPairSave()
        try expect(changedPairSavedCaptions?.primary.cues.first?.text == "日本語。"
                   && changedPairSavedCaptions?.secondary.cues.first?.text == "Français."
                   && changedPairSavedCaptions?.primaryOffset == 1.25 && changedPairSavedCaptions?.secondaryOffset == -0.25,
                   "pending-pair save mixed retained old tracks or lost the save-time offsets")
        let readySave = model.makeVideoSubtitleSaveProvider()
        model.slots[0].offset = 20
        let readySavedCaptions = await readySave()
        try expect(readySavedCaptions?.primaryOffset == 8 && readySavedCaptions?.secondaryOffset == 9,
                   "ready subtitle save snapshot changed after a later timing edit")
        try expect(model.slots[0].track.cues.first?.text == "日本語。" && model.slots[1].track.cues.first?.text == "Français.",
                   "changing the language pair did not automatically fetch the new pair")
        try expect(model.currentTime == 42 && model.speed == 0.75, "subtitle language change reset playback")
        try expect(snapshot?.primary.cues.first?.text == "English first.", "later caption selection mutated a saved media snapshot")
        model.primaryCaptionLanguage = "en"
        model.secondaryCaptionLanguage = "de"
        try await settleCaptions(model)
        try expect(model.slots[0].track.cues.first?.text == "English refresh." && model.slots[1].track.cues.first?.text == "Français.",
                   "partial refresh failed to keep first-track progress and the previous second track")
        try expect(model.slots[1].websiteTrack?.languageCode == "fr" && model.notice.english.contains("previous second"),
                   "retained translation was mislabeled or not explained after the replacement failed")
        model.primaryCaptionLanguage = "fr"
        try await settleCaptions(model)
        try expect(fetcher.error != nil && model.slots[0].track.cues.first?.text == "English refresh."
                   && model.slots[1].track.cues.first?.text == "Français.", "first-track failure discarded existing subtitles")
        try expect(model.canSaveVideo, "caption failure disabled Save Video")
        model.primaryCaptionLanguage = "en"
        model.secondaryCaptionLanguage = "zh-Hant"
        let oldVideoSave = model.makeVideoSubtitleSaveProvider()
        model.beginYouTubeSubtitleSession(other)
        try await settleCaptions(model)
        let oldVideoSavedCaptions = await oldVideoSave()
        try expect(oldVideoSavedCaptions == nil, "new video's subtitles contaminated a pending old-video save")
        try expect(model.slots[0].track.cues.first?.text == "Other video." && model.slots[1].track.cues.first?.text == "另一影片。",
                   "a delayed old-video selection overwrote the new video's tracks")
        try expect(model.slots.allSatisfy { $0.offset == 0 }, "new video inherited previous video's subtitle offsets")
        model.primaryCaptionLanguage = "ja"
        let cancelledPairSave = model.makeVideoSubtitleSaveProvider()
        model.secondaryCaptionLanguage = "es"
        let cancelledPairSnapshot = await cancelledPairSave()
        try expect(cancelledPairSnapshot == nil, "a different language pair contaminated the pending save")
        try await settleCaptions(model)
        let missing = try YouTubeLink.parse("XbCdEf_12-3")
        model.beginYouTubeSubtitleSession(missing)
        let noCaptionSave = model.makeVideoSubtitleSaveProvider()
        let noCaptionSnapshot = await noCaptionSave()
        try expect(fetcher.error != nil && noCaptionSnapshot == nil && model.canSaveVideo,
                   "an unavailable initial caption request prevented video-only saving")
        model.videoSaver.saveLocal(mediaURL: directory.appendingPathComponent("absent.mp4"), snapshot: nil,
            destinationDirectory: directory) { _ in }
        try expect(model.videoSaver.isSaving && !model.canSaveVideo, "own in-progress save did not prevent duplicate Save actions")
        model.videoSaver.cancel()
        try expect(model.canSaveVideo, "cancelling a save left Save Video disabled")
        try expect(model.youtube?.webView?.url == nil && model.player.currentItem == nil,
                   "caption workflow tests started a web or media player")
        model.youtube = nil
        model.cancelYouTubeCaptions()
        try await settled(model)
        print("PASS automatic en/Traditional captions, reload reuse, automatic pair changes, partial failure retention, video isolation, synchronized save snapshots")
    }

    static func checkSubtitleExports(_ model: PlayerModel, directory: URL) async throws {
        model.live.enabled = false
        model.sentenceMode = false
        model.slots = [
            SubtitleSlot(name: "original", track: SubtitleTrack(cues: [cue(1, 1, 3, "First\nline.")])),
            SubtitleSlot(name: "translation", track: SubtitleTrack(cues: [cue(2, 1, 3, "中文 🌏")]))
        ]
        try expect(!model.hasMedia && model.canExportSubtitles, "subtitle-only session cannot export")
        let snapshot = try model.makeSubtitleExportSnapshot()
        let rendered = try snapshot.render()
        try expect(rendered.text.contains("First\nline.\n中文 🌏"), "export did not retain original before translation")
        let textWithoutMedia = try snapshot.render(format: .txt)
        let textWithoutMediaString = String(data: textWithoutMedia.data, encoding: .utf8)
        try expect(textWithoutMediaString?.contains("First\nline.") == true && textWithoutMediaString?.contains("中文 🌏") == true,
                   "TXT export without media lost UTF-8 text")
        let wordWithoutMedia = try snapshot.render(format: .docx)
        try expect(wordWithoutMedia.data.starts(with: [0x50, 0x4b, 0x03, 0x04]) && wordWithoutMedia.cueCount > 0,
                   "DOCX export without media did not produce a ZIP document")
        model.search = "no matching rows"
        model.selectPanel(1)
        model.slots[0].isVisible = false
        model.slots[1].isVisible = false
        let hidden = try model.makeSubtitleExportSnapshot().render()
        try expect(hidden.text == rendered.text, "selection, search or visibility changed exported content/order")
        model.slots[0].track = SubtitleTrack(cues: [cue(3, 8, 9, "Replacement")])
        model.slots[0].offset = 4
        let retained = try snapshot.render()
        try expect(retained.text == rendered.text, "slot mutation changed a previously captured export")
        let retainedText = try snapshot.render(format: .txt)
        try expect(retainedText.data == textWithoutMedia.data, "slot mutation changed the captured TXT export")
        print("PASS export ignores panel/search/visibility and retains an immutable snapshot without media")

        model.slots = [
            SubtitleSlot(name: "fragments", track: SubtitleTrack(cues: [cue(1, 0, 1, "Good\nmorning"), cue(2, 1, 2, "everyone.")])),
            SubtitleSlot(name: "translation", track: SubtitleTrack(cues: [cue(3, 0, 2, "早上好。")]))
        ]
        model.sentenceMode = true
        try expect(model.sentencesBuilding && !model.canExportSubtitles, "grouping export was enabled before a complete result")
        try expectFailure("snapshot accepted incomplete sentence grouping") { _ = try model.makeSubtitleExportSnapshot() }
        try await settled(model)
        let grouped = try model.makeSubtitleExportSnapshot().render()
        try expect(grouped.text.contains("Good morning everyone.\n早上好。"), "export ignored current sentence mode")
        model.sentenceMode = false
        let raw = try model.makeSubtitleExportSnapshot().render()
        try expect(raw.text.contains("Good\nmorning") && raw.text != grouped.text, "raw export silently retained grouped text")
        print("PASS export waits for grouping and follows the current raw/sentence mode")

        model.slots = [SubtitleSlot(), SubtitleSlot(name: "Chinese only", track: SubtitleTrack(cues: [cue(1, 1, 2, "仅有译文。")]))]
        let chineseOnly = try model.makeSubtitleExportSnapshot()
        let chineseOnlyOutput = try chineseOnly.render()
        try expect(model.canExportSubtitles && chineseOnly.primary.cues.isEmpty && chineseOnlyOutput.text.contains("仅有译文。"),
                   "translation-only export was lost")
        model.slots = [SubtitleSlot(name: "English only", track: SubtitleTrack(cues: [cue(1, 1, 2, "Original only.")])), SubtitleSlot()]
        let englishOnly = try model.makeSubtitleExportSnapshot()
        let englishOnlyOutput = try englishOnly.render()
        try expect(model.canExportSubtitles && englishOnly.secondary.cues.isEmpty && englishOnlyOutput.text.contains("Original only."),
                   "original-only export was lost")

        model.live.enabled = true
        model.live.chineseEnabled = false
        model.live.transcript = LiveTranscript()
        model.live.transcript.update(text: "Confirmed", start: 1, end: 2, isFinal: true, finalizedThrough: 2)
        let confirmedID = model.live.transcript.captions[0].id
        model.live.transcript.translate(id: confirmedID, source: "Confirmed", text: "已确认")
        model.live.transcript.update(text: "Translation pending", start: 3, end: 4, isFinal: true, finalizedThrough: 4)
        model.live.transcript.update(text: "Unfinished draft", start: 5, end: 6, isFinal: false, finalizedThrough: 4)
        let liveSnapshot = try model.makeSubtitleExportSnapshot()
        let liveOutput = try liveSnapshot.render()
        let liveTextOutput = try liveSnapshot.render(format: .txt)
        let liveText = String(data: liveTextOutput.data, encoding: .utf8) ?? ""
        try expect(liveText.contains("Confirmed") && liveText.contains("Translation pending") && liveText.contains("已确认")
                   && !liveText.contains("Unfinished draft") && !liveText.contains("Original only."),
                   "live TXT export omitted final content or included drafts/file subtitles")
        try expect(liveSnapshot.primary.cues.map(\.text) == ["Confirmed", "Translation pending"], "live export included draft or omitted final text")
        try expect(liveSnapshot.secondary.cues.map(\.text) == ["已确认"], "live export lost existing translation while its display was disabled")
        try expect(liveSnapshot.primaryOffset == 0 && liveSnapshot.secondaryOffset == 0, "live export inherited file subtitle offsets")
        try expect(!liveOutput.text.contains("Unfinished draft") && !liveOutput.text.contains("Original only."), "live export mixed drafts or file subtitles")
        model.live.transcript.translate(id: confirmedID, source: "Confirmed", text: "稍后更新")
        model.live.transcript.update(text: "Later final", start: 5, end: 6, isFinal: true, finalizedThrough: 6)
        let retainedLive = try liveSnapshot.render()
        try expect(retainedLive.text == liveOutput.text, "later ASR/translation changed captured live export")
        let retainedLiveText = try liveSnapshot.render(format: .txt)
        try expect(retainedLiveText.data == liveTextOutput.data, "later ASR/translation changed captured live TXT export")
        model.live.transcript = LiveTranscript()
        model.live.transcript.update(text: "Draft only", start: 1, end: 2, isFinal: false, finalizedThrough: 0)
        try expect(!model.canExportSubtitles, "draft-only live session enabled export")
        try expectFailure("draft-only live snapshot did not fail") { _ = try model.makeSubtitleExportSnapshot() }
        model.live.enabled = false
        model.slots = [SubtitleSlot(), SubtitleSlot()]
        try expect(!model.canExportSubtitles, "empty tracks enabled export")
        try expectFailure("empty subtitle snapshot did not fail") { _ = try model.makeSubtitleExportSnapshot() }
        print("PASS either single track exports; live export includes only final text and existing translations")

        let englishURL = directory.appendingPathComponent("export-source.en.srt")
        let chineseURL = directory.appendingPathComponent("export-source.zh.srt")
        let mediaURL = directory.appendingPathComponent("export-source.mp4")
        let englishData = Data("1\n00:00:01,000 --> 00:00:02,000\nSaved original.\n\n".utf8)
        let chineseData = Data("1\n00:00:01,000 --> 00:00:02,000\n保存中文 🌏\n\n".utf8)
        let mediaData = Data("fixture only; never opened as media".utf8)
        try englishData.write(to: englishURL)
        try chineseData.write(to: chineseURL)
        try mediaData.write(to: mediaURL)
        model.loadSubtitle(englishURL, slot: 0)
        model.loadSubtitle(chineseURL, slot: 1)
        model.mediaURL = mediaURL // Protect a source path without opening AVPlayer or invoking Speech.
        try expect(model.canSaveVideo, "local media with captions did not enable Save Video")
        try expect(model.slots[0].sourceURL == englishURL && model.slots[1].sourceURL == chineseURL, "loadSubtitle did not retain source URLs")
        let fileSnapshot = try model.makeSubtitleExportSnapshot()
        let protectedPaths = Set(fileSnapshot.sourceURLs.map { $0.standardizedFileURL.resolvingSymlinksInPath().path })
        for source in [englishURL, chineseURL, mediaURL] {
            try expect(protectedPaths.contains(source.standardizedFileURL.resolvingSymlinksInPath().path), "snapshot omitted a protected source")
            try expectFailure("export overwrote source \(source.lastPathComponent)") { _ = try fileSnapshot.write(to: source) }
        }
        for format in SubtitleExportFormat.allCases {
            for (index, source) in [englishURL, mediaURL].enumerated() {
                let aliasURL = directory.appendingPathComponent("export-source-alias-\(index).\(format.rawValue)")
                try FileManager.default.createSymbolicLink(at: aliasURL, withDestinationURL: source)
                try expectFailure("\(format.rawValue) export accepted a symlink to a subtitle/media source") {
                    _ = try fileSnapshot.write(to: aliasURL, format: format)
                }
            }
        }
        let englishAfter = try Data(contentsOf: englishURL)
        let chineseAfter = try Data(contentsOf: chineseURL)
        let mediaAfter = try Data(contentsOf: mediaURL)
        try expect(englishAfter == englishData && chineseAfter == chineseData && mediaAfter == mediaData, "source bytes changed after rejected exports")
        let destination = directory.appendingPathComponent("export-bilingual.srt")
        let written = try fileSnapshot.write(to: destination)
        let diskText = try String(contentsOf: destination, encoding: .utf8)
        try expect(Data(diskText.utf8) == written.data && diskText.contains("保存中文 🌏") && written.cueCount > 0, "saved UTF-8 export did not round-trip")
        try expect(!fileSnapshot.suggestedName.isEmpty, "export has no suggested filename")
        for format in [SubtitleExportFormat.docx, .txt] {
            let name = fileSnapshot.suggestedName(for: format)
            try expect((name as NSString).pathExtension == format.rawValue && !(name as NSString).deletingPathExtension.hasSuffix(".srt"),
                       "suggested filename retained the wrong format extension")
            let formattedDestination = directory.appendingPathComponent("export-bilingual.\(format.rawValue)")
            let formattedOutput = try fileSnapshot.write(to: formattedDestination, format: format)
            let diskData = try Data(contentsOf: formattedDestination)
            try expect(diskData == formattedOutput.data && formattedOutput.cueCount > 0,
                       "\(format.rawValue) file differs from the generated output")
            if format == .txt {
                let savedText = String(data: diskData, encoding: .utf8) ?? ""
                try expect(savedText.contains("Saved original.") && savedText.contains("保存中文 🌏"), "saved TXT is not readable bilingual UTF-8")
            } else {
                try expect(diskData.starts(with: [0x50, 0x4b, 0x03, 0x04]), "saved DOCX has no ZIP signature")
            }
            let wrongExtension = format == .txt ? "docx" : "txt"
            let mismatch = directory.appendingPathComponent("export-format-mismatch.\(wrongExtension)")
            let sentinel = Data("existing destination must remain unchanged".utf8)
            try sentinel.write(to: mismatch)
            try expectFailure("export accepted a filename inconsistent with \(format.rawValue)") {
                _ = try fileSnapshot.write(to: mismatch, format: format)
            }
            let mismatchAfter = try Data(contentsOf: mismatch)
            try expect(mismatchAfter == sentinel, "format mismatch modified the existing destination")
        }
        model.clearSubtitle(slot: 0)
        model.clearSubtitle(slot: 1)
        try expect(model.slots.allSatisfy { $0.sourceURL == nil }, "clearing subtitles retained stale source paths")
        try expect(model.canSaveVideo && model.makeVideoSubtitleSnapshot() == nil,
                   "local media without subtitles could not be saved on its own")
        model.mediaURL = nil
        try expect(model.player.currentItem == nil && model.youtube == nil && !model.live.running, "export checks started media, web or speech")
        print("PASS SRT/DOCX/TXT write matching bytes; format mismatches and source symlinks are rejected; UTF-8 output round-trips")
    }

    static func main() async throws {
        guard let domain = Bundle.main.bundleIdentifier,
              domain.hasPrefix("io.github.axonvoss-labs.axontube.integration."),
              domain == CommandLine.arguments[1] else {
            throw CheckFailure(description: "refusing to run outside the isolated preference domain")
        }
        let mode = CommandLine.arguments[2]
        let preferences = UserDefaults.standard
        if mode == "cleanup" {
            preferences.removePersistentDomain(forName: domain)
            preferences.synchronize()
            return
        }
        if mode == "preferences-write" {
            preferences.removePersistentDomain(forName: domain)
            let model = PlayerModel()
            model.subtitleSize = 37
            model.subtitleListSize = 19
            model.sentenceMode = false
            model.primaryCaptionLanguage = "ja"
            model.secondaryCaptionLanguage = "fr"
            L10n.language = .simplifiedChinese
            preferences.synchronize()
            try expect(preferences.double(forKey: "subtitle.fontSize") == 37, "font size was not saved")
            try expect(preferences.double(forKey: "subtitle.listFontSize") == 19, "list font size was not saved")
            print("PASS preferences written by actual PlayerModel setters in isolated bundle domain")
            return
        }
        if mode == "preferences-read" {
            try expect(L10n.language == .simplifiedChinese, "interface language was not restored in a new process")
            let model = PlayerModel()
            try expect(model.subtitleSize == 37 && model.subtitleListSize == 19, "new process did not restore saved sizes")
            try expect(!model.sentenceMode, "new process did not restore sentence mode")
            try expect(model.primaryCaptionLanguage == "ja" && model.secondaryCaptionLanguage == "fr", "caption language choices did not persist")
            preferences.set(100.0, forKey: "subtitle.fontSize")
            preferences.set(2.0, forKey: "subtitle.listFontSize")
            let clamped = PlayerModel()
            try expect(clamped.subtitleSize == 48 && clamped.subtitleListSize == 12, "initial size bounds not enforced")
            print("PASS separate process restores sizes/mode and clamps invalid ranges")
            return
        }
        guard mode == "integration" else { throw CheckFailure(description: "unknown mode") }
        preferences.removePersistentDomain(forName: domain)
        let model = PlayerModel()
        try expect(model.subtitleSize == 24 && model.subtitleListSize == 14 && model.sentenceMode, "fresh defaults changed")
        try expect(model.youtube == nil && model.player.currentItem == nil, "test unexpectedly opened a source")
        try expect(L10n.language == .english, "fresh install must default to English independently of system locale")
        try expect(model.primaryCaptionLanguage == "en" && model.secondaryCaptionLanguage == "zh-Hant", "fresh caption defaults must be English and Traditional Chinese")
        let idleMessage = model.notice
        let initialModel = ObjectIdentifier(model)
        model.currentTime = 37
        model.speed = 0.75
        let initialLiveStatus = model.live.status
        L10n.language = .simplifiedChinese
        try expect(model.notice.text == idleMessage.chinese && model.live.status.text == initialLiveStatus.chinese,
                   "language switch did not translate existing controller messages")
        try expect(model.currentTime == 37 && model.speed == 0.75 && ObjectIdentifier(model) == initialModel,
                   "language switch reset playback state")
        L10n.language = .english
        try expect(model.notice.text == idleMessage.english, "switching back did not restore English")
        preferences.set("unsupported-locale", forKey: L10n.preferenceKey)
        try expect(L10n.language == .english, "unknown stored locale must fall back to English")
        L10n.language = .english
        model.currentTime = 0
        model.speed = 1
        print("PASS English default, persisted language, dynamic messages, and playback-state preservation")

        let original = [cue(10, 0, 1, "Good\nmorning"), cue(11, 1, 2, "everyone.")]
        model.slots[0] = SubtitleSlot(name: "fixture", track: SubtitleTrack(cues: original))
        try expect(model.sentencesBuilding, "slot assignment did not schedule asynchronous grouping")
        await Task.yield()
        try await settled(model)
        try expect(model.learningTrack.cues.map(\.text) == ["Good morning everyone."], "grouped display not installed")
        try expect(model.learningTrack.cues[0].start == 0 && model.learningTrack.cues[0].end == 2, "source interval changed")
        let groupedEnglish = model.learningTrack.cues
        model.loopEnabled = true
        model.loopCueID = groupedEnglish[0].id
        model.slots[1].track = SubtitleTrack(cues: [cue(20, 0.1, 1.9, "早上\n好。")])
        try await settled(model)
        try expect(model.learningTrack.cues == groupedEnglish, "later Chinese changed the English group")
        try expect(model.loopEnabled && model.loopCueID == groupedEnglish[0].id, "later Chinese reset the loop")
        try expect(model.pairedText(for: groupedEnglish[0]) == "早上好。", "group ID pairing failed")
        print("PASS async slot grouping; later translation preserves English group and loop")

        model.sentenceMode = false
        try expect(model.learningTrack.cues == original, "raw mode did not return original cues")
        model.currentTime = 0.5
        try expect(model.activeText(slot: 0) == "Good\nmorning", "raw line breaks were not preserved")
        model.sentenceMode = true
        try await settled(model)
        print("PASS sentence mode off restores original text, cue IDs and intervals")

        model.slots = [
            SubtitleSlot(name: "English", track: SubtitleTrack(cues: [cue(1, 10, 14, "One sentence.")]), offset: 2),
            SubtitleSlot(name: "Chinese", track: SubtitleTrack(cues: [cue(2, 10, 14, "一句译文。")]), offset: 2.5)
        ]
        try await settled(model)
        try expect(model.learningOffset == 0 && model.learningTrack.cues[0].start == 12 && model.learningTrack.cues[0].end == 16,
                   "English offset was not baked exactly once")
        let shiftedGroupedExport = try model.makeSubtitleExportSnapshot()
        try expect(shiftedGroupedExport.primaryOffset == 0 && shiftedGroupedExport.secondaryOffset == 0
                   && shiftedGroupedExport.primary.cues.first?.start == 12 && shiftedGroupedExport.secondary.cues.first?.start == 12.5,
                   "grouped export did not retain independent clocks with offsets baked once")
        let shiftedGroupedOutput = try shiftedGroupedExport.render()
        model.currentTime = 12.25
        try expect(model.activeText(slot: 0) == "One sentence." && model.activeText(slot: 1).isEmpty, "Chinese offset was lost to English clock")
        model.currentTime = 12.75
        try expect(model.activeText(slot: 1) == "一句译文。", "Chinese did not start on its own shifted clock")
        model.currentTime = 16.25
        try expect(model.activeText(slot: 0).isEmpty && model.activeText(slot: 1) == "一句译文。", "Chinese end shifted to English end")
        model.selectPanel(1)
        try expect(model.learningOffset == 0 && model.learningTrack.cues[0].start == 12.5 && model.learningTrack.cues[0].end == 16.5,
                   "Chinese learning clock applied offset twice")
        model.sentenceMode = false
        try expect(model.learningOffset == 2.5 && model.learningTrack.cues[0].start == 10, "raw mode lost original offset separation")
        let shiftedRawExport = try model.makeSubtitleExportSnapshot()
        let shiftedRawOutput = try shiftedRawExport.render()
        try expect(shiftedRawExport.primaryOffset == 2 && shiftedRawExport.secondaryOffset == 2.5,
                   "raw export lost independent file offsets")
        try expect(shiftedRawOutput.text == shiftedGroupedOutput.text, "raw/grouped export applied file offsets differently")
        model.currentTime = 12.75
        try expect(model.activeText(slot: 1) == "一句译文。", "raw/grouped offset semantics disagree")
        model.selectPanel(0)
        model.sentenceMode = true
        print("PASS independent positive offsets applied once in grouped and raw modes")

        model.slots = [
            SubtitleSlot(name: "negative English", track: SubtitleTrack(cues: [cue(0, 0, 0.5, "past"), cue(1, 0.5, 1.5, "Hello"), cue(2, 1.5, 2.5, "there.")]), offset: -1),
            SubtitleSlot(name: "negative Chinese", track: SubtitleTrack(cues: [cue(0, 0.25, 1.25, "你好。")]), offset: -0.75)
        ]
        try await settled(model)
        try expect(model.learningTrack.cues.map(\.text) == ["Hello there."], "fully negative cue was not dropped")
        try expect(model.learningTrack.cues[0].start == 0 && model.learningTrack.cues[0].end == 1.5, "negative crossing-zero clip wrong")
        model.currentTime = 0.25
        try expect(model.activeText(slot: 0) == "Hello there." && model.activeText(slot: 1) == "你好。", "clipped captions unavailable at playback zero")
        model.currentTime = 0.75
        try expect(model.activeText(slot: 1).isEmpty, "negative Chinese end ignored")
        try expect(model.slots[0].track.cues[0].start == 0 && model.slots[0].track.cues[1].start == 0.5,
                   "grouping changed original subtitle source")
        let negativeExport = try model.makeSubtitleExportSnapshot()
        try expect(negativeExport.primaryOffset == 0 && negativeExport.secondaryOffset == 0
                   && negativeExport.primary.cues.first?.start == 0 && negativeExport.primary.cues.first?.end == 1.5,
                   "negative grouped export lost clipping or would apply offsets twice")
        model.sentenceMode = false
        let negativeRawExport = try model.makeSubtitleExportSnapshot()
        let negativeRawOutput = try negativeRawExport.render()
        try expect(negativeRawExport.primaryOffset == -1 && negativeRawExport.secondaryOffset == -0.75,
                   "negative raw export lost the original file offsets")
        try expect(negativeRawOutput.text.contains("00:00:00,000") && !negativeRawOutput.text.contains("past"),
                   "negative raw export failed to clip the beginning or retained a fully expired cue")
        model.sentenceMode = true
        try await settled(model)
        print("PASS negative offsets clip crossing-zero cues without modifying original tracks")

        model.live.enabled = true
        model.live.running = false
        model.live.transcript.update(text: "Live history", start: 5, end: 6, isFinal: true, finalizedThrough: 6)
        let liveID = model.live.transcript.captions[0].id
        model.live.transcript.translate(id: liveID, source: "Live history", text: "实时历史")
        model.currentTime = 5.5
        try expect(model.activeText(slot: 0) == "Live history" && model.activeText(slot: 1) == "实时历史", "nonrunning live history unavailable")
        model.slots[0].isVisible = false
        try expect(model.activeText(slot: 0).isEmpty && model.activeText(slot: 1) == "实时历史", "live English visibility ignored")
        model.slots[1].isVisible = false
        try expect(model.activeText(slot: 1).isEmpty, "live Chinese visibility ignored")
        model.slots[0].isVisible = true
        model.slots[1].isVisible = true
        model.live.chineseEnabled = false
        try expect(model.activeText(slot: 1).isEmpty, "live Chinese language toggle ignored")
        model.live.enabled = false
        print("PASS per-track visibility and Chinese toggle apply to nonrunning live transcript")

        let fixture = URL(fileURLWithPath: CommandLine.arguments[3]).appendingPathComponent("new.vtt")
        try Data("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nFresh result.\n".utf8).write(to: fixture)
        let manyCues = (0..<20_000).map { cue($0, Double($0) * 0.2, Double($0 + 1) * 0.2, "Old fragment of a sentence") }
        model.slots = [SubtitleSlot(name: "old heavy", track: SubtitleTrack(cues: manyCues)), SubtitleSlot()]
        let oldOuter = task("sentenceTask", in: model, as: Task<Void, Never>.self)
        let oldWorker = try await startedWorker(model)
        model.loadSubtitle(fixture, slot: 0)
        try expect(oldWorker.isCancelled, "replacing subtitle did not cancel detached worker")
        _ = await oldWorker.value
        await oldOuter?.value
        try await settled(model)
        try expect(model.learningTrack.cues.map(\.text) == ["Fresh result."], "old background result overwrote new file")
        print("PASS real loadSubtitle cancels old worker; late result cannot overwrite new subtitles")

        model.slots = [SubtitleSlot(name: "old heavy", track: SubtitleTrack(cues: manyCues)), SubtitleSlot()]
        let clearedOuter = task("sentenceTask", in: model, as: Task<Void, Never>.self)
        let clearedWorker = try await startedWorker(model)
        model.clearSubtitle(slot: 0)
        try expect(clearedWorker.isCancelled, "clear did not cancel detached worker")
        _ = await clearedWorker.value
        await clearedOuter?.value
        try expect(model.learningTrack.cues.isEmpty && !model.sentencesBuilding, "old result restored a cleared track")
        print("PASS clearSubtitle cancels old worker and remains empty after old tasks finish")

        model.loadSubtitle(fixture, slot: 0)
        for index in 0..<30 { model.slots[0].offset = Double(index) / 10 }
        try await settled(model)
        try expect(abs((model.learningTrack.cues.first?.start ?? -1) - 3.9) < 0.000_001,
                   "rapid offset changes did not keep latest generation")
        try expect(model.learningOffset == 0, "rapid rebuild double-applied the latest offset")
        try expect(model.youtube == nil && model.player.currentItem == nil && !model.live.running,
                   "integration checks unexpectedly started a media or speech session")
        print("PASS rapid offset changes retain only newest generation")
        model.clearSubtitle(slot: 0)
        try await checkSubtitleExports(model, directory: fixture.deletingLastPathComponent())
        try await checkAutomaticYouTubeCaptions(directory: fixture.deletingLastPathComponent())
        print("MODEL CHECKS: \(assertions) assertions passed; no GUI, network, media or model preparation invoked")
    }
}
'''
(work / "ModelChecks.swift").write_text(harness)
core_sources = sorted((root / "Sources/PlayerCore").glob("*.swift"))
app_sources = sorted(p for p in (root / "Sources/AxonTube").glob("*.swift") if p.name != "App.swift")
source_hashes = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in core_sources + app_sources}
target = platform.machine() + "-apple-macosx14.0"
common = ["xcrun", "swiftc", "-swift-version", "5", "-target", target]
subprocess.run(common + ["-parse-as-library", "-emit-library", "-emit-module", "-module-name", "PlayerCore",
    "-emit-module-path", str(modules / "PlayerCore.swiftmodule"),
    *map(str, core_sources), "-o", str(frameworks / "libPlayerCore.dylib"),
    "-Xlinker", "-install_name", "-Xlinker", "@rpath/libPlayerCore.dylib"], check=True)
subprocess.run(common + ["-parse-as-library", "-module-name", "ModelChecks", "-I", str(modules),
    "-L", str(frameworks), "-lPlayerCore", *map(str, app_sources), str(work / "ModelChecks.swift"),
    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks", "-o", str(executable)], check=True)
print("Temporary integration bundle:", app, flush=True)
try:
    for mode in ("preferences-write", "preferences-read", "integration"):
        subprocess.run([str(executable), bundle_id, mode, str(work)], check=True, timeout=45)
finally:
    subprocess.run([str(executable), bundle_id, "cleanup", str(work)], check=True, timeout=10)
changed = [str(p.relative_to(root)) for p, digest in source_hashes.items() if hashlib.sha256(p.read_bytes()).hexdigest() != digest]
if changed:
    raise SystemExit("Sources changed during compilation/checks; rerun against the final version: " + ", ".join(changed))
