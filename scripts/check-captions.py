#!/usr/bin/env python3
"""Offline checks of real caption-cache and request cancellation behavior."""
from pathlib import Path
import subprocess, tempfile

root = Path(__file__).resolve().parents[1]
work = Path(tempfile.mkdtemp(prefix="axontube-caption-check-"))
harness = r'''
@main @MainActor struct CaptionIntegrationChecks {
    static var assertions = 0
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        assertions += 1
        if !value() { throw NSError(domain: "CaptionChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func settle(_ fetcher: YouTubeCaptionFetcher) async throws {
        let end = Date().addingTimeInterval(5)
        while (fetcher.isFetching || fetcher.isLoadingLanguages) && Date() < end { try await Task.sleep(for: .milliseconds(5)) }
        try expect(!fetcher.isFetching && !fetcher.isLoadingLanguages, "request did not settle")
    }
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let link = try YouTubeLink.parse("AbCdEf_12-3")
        let json = Data(#"{"id":"AbCdEf_12-3","subtitles":{"en":[{"ext":"vtt"}]},"automatic_captions":{"zh-Hant-en":[{"ext":"vtt"}],"zh-Hans-en":[{"ext":"vtt"}]}}"#.utf8)
        let plan = try YouTubeCaptionPlan.select(metadata: json, for: link, primaryLanguage: "en", secondaryLanguage: "zh-Hant")
        let key = YouTubeCaptionFetcher.cacheKey(primaryLanguage: "en", secondaryLanguage: "zh-Hant")
        try expect(key.count == 64, "cache key is not SHA256")
        try expect(key != YouTubeCaptionFetcher.cacheKey(primaryLanguage: "en", secondaryLanguage: "zh-Hans"), "second selection not isolated")
        try expect(key != YouTubeCaptionFetcher.cacheKey(primaryLanguage: "zh-Hant", secondaryLanguage: "en"), "ordered choices not isolated")
        try expect(key != YouTubeCaptionFetcher.cacheKey(primaryLanguage: "manual:en", secondaryLanguage: "zh-Hant"), "exact choice not isolated")
        let directory = root.appendingPathComponent(link.videoID).appendingPathComponent(key)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let primary = directory.appendingPathComponent("primary.vtt")
        let secondary = directory.appendingPathComponent("secondary.vtt")
        try Data("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nFirst track.\n".utf8).write(to: primary)
        try Data("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n繁體字幕。\n".utf8).write(to: secondary)
        let a = try CaptionCache.validate(at: primary), b = try CaptionCache.validate(at: secondary)
        try CaptionCache.write(plan: plan, videoID: link.videoID, directory: directory, primaryDigest: a.digest, secondaryDigest: b.digest)
        let read = CaptionCache.read(directory: directory, videoID: link.videoID, primaryLanguage: "en", secondaryLanguage: "zh-Hant")
        try expect(read?.primaryCues.first?.text == "First track.", "first cache track lost")
        try expect(read?.secondaryCues?.first?.text == "繁體字幕。", "second cache track lost")
        try expect(CaptionCache.read(directory: directory, videoID: link.videoID, primaryLanguage: "en", secondaryLanguage: "zh-Hans") == nil, "mismatched choices accepted")
        try expect(CaptionCache.read(directory: directory, videoID: "ZbCdEf_12-3", primaryLanguage: "en", secondaryLanguage: "zh-Hant") == nil, "wrong video accepted")
        let fetcher = YouTubeCaptionFetcher(allowLocalFallback: false, cacheRoot: root)
        var results: [YouTubeCaptionResult] = []
        fetcher.fetch(link: link, primaryLanguage: "en", secondaryLanguage: "zh-Hant") { results.append($0) }
        try await settle(fetcher)
        try expect(results.count == 1 && results[0].isComplete, "complete cache did not work without helper")
        try expect(results[0].primaryLanguage == "en" && results[0].secondaryLanguage == "zh-Hant", "result lost request identity")
        try expect(results[0].primaryTrack.id == "manual:en" && results[0].secondaryTrack?.id == "automatic:zh-Hant-en", "result lost source identity")
        try expect(results[0].primaryURL == primary && results[0].secondaryURL == secondary, "result URLs wrong")
        try expect(fetcher.error == nil, "cache path reported helper error")
        results = []
        fetcher.fetch(link: link, primaryLanguage: "en", secondaryLanguage: "zh-Hant") { results.append($0) }
        fetcher.cancel()
        try await Task.sleep(for: .milliseconds(100))
        try expect(results.isEmpty && !fetcher.isFetching, "cancelled fetch published cached result")
        fetcher.fetch(link: link, primaryLanguage: "en", secondaryLanguage: "zh-Hant") { results.append($0) }
        fetcher.fetch(link: link, primaryLanguage: "en", secondaryLanguage: "zh-Hans") { results.append($0) }
        try await settle(fetcher)
        try await Task.sleep(for: .milliseconds(30))
        try expect(results.isEmpty, "superseded selection published old captions")
        try expect(fetcher.error != nil, "missing selected cache should require unavailable helper")
        fetcher.discoverLanguages(link: link)
        try expect(fetcher.languageRequestVideoID == link.videoID, "lookup lost requested video identity")
        let otherLink = try YouTubeLink.parse("ZbCdEf_12-3")
        fetcher.discoverLanguages(link: otherLink)
        try expect(fetcher.languageRequestVideoID == otherLink.videoID, "new lookup retained old video identity")
        fetcher.cancelLanguageDiscovery()
        try expect(!fetcher.isLoadingLanguages, "link change left language button busy")
        fetcher.cancel()
        try await Task.sleep(for: .milliseconds(30))
        try expect(!fetcher.isLoadingLanguages && fetcher.catalogVideoID == nil && fetcher.catalog.isEmpty, "cancelled catalog leaked state")
        fetcher.discoverLanguages(link: link)
        try await settle(fetcher)
        try expect(fetcher.languageError != nil && fetcher.catalog.isEmpty, "missing helper did not report catalog failure")
        try expect(fetcher.languageStatus.english.contains("could not be loaded"), "catalog status not useful")
        try Data("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nChanged first.\n".utf8).write(to: primary)
        try expect(CaptionCache.read(directory: directory, videoID: link.videoID, primaryLanguage: "en", secondaryLanguage: "zh-Hant") == nil, "changed first bytes accepted")
        let changed = try CaptionCache.validate(at: primary)
        try CaptionCache.write(plan: plan, videoID: link.videoID, directory: directory, primaryDigest: changed.digest, secondaryDigest: nil)
        let partial = CaptionCache.read(directory: directory, videoID: link.videoID, primaryLanguage: "en", secondaryLanguage: "zh-Hant")
        try expect(partial?.primaryCues.first?.text == "Changed first.", "partial first track not retained")
        try expect(partial?.secondaryCues == nil, "stale second track reused without manifest binding")
        var manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("plan.json"))) as! [String: Any]
        var saved = manifest["plan"] as! [String: Any]
        saved["secondaryLanguage"] = "zh-Hans"
        manifest["plan"] = saved
        try JSONSerialization.data(withJSONObject: manifest).write(to: directory.appendingPathComponent("plan.json"))
        try expect(CaptionCache.read(directory: directory, videoID: link.videoID, primaryLanguage: "en", secondaryLanguage: "zh-Hant") == nil, "tampered plan options accepted")
        print("FETCHER CHECKS: \(assertions) assertions passed; no helper, network, GUI, or media invoked")
    }
}
'''
# Compile the unmodified fetcher with its tests to exercise file-private cache code.
source = (root / "Sources/AxonTube/YouTubeCaptionFetcher.swift").read_text()
(work / "FetcherChecks.swift").write_text(source + "\n" + harness)
core = sorted((root / "Sources/PlayerCore").glob("*.swift"))
subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-emit-library", "-emit-module",
    "-module-name", "PlayerCore", "-emit-module-path", str(work / "PlayerCore.swiftmodule"),
    *map(str, core), "-o", str(work / "libPlayerCore.dylib"),
    "-Xlinker", "-install_name", "-Xlinker", "@rpath/libPlayerCore.dylib"], check=True)
subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-I", str(work), "-L", str(work),
    "-lPlayerCore", str(work / "FetcherChecks.swift"), "-Xlinker", "-rpath", "-Xlinker", str(work),
    "-o", str(work / "checks")], check=True)
subprocess.run([str(work / "checks"), str(work / "cache")], check=True)
