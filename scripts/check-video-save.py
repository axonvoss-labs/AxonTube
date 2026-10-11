#!/usr/bin/env python3
"""Offline Save Video integration checks using the real controller and a fake helper."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
work = Path(tempfile.mkdtemp(prefix="axontube-save-check-"))
fake = work / "fake-yt-dlp"
fake.write_text("""#!/usr/bin/python3
import json, pathlib, sys, time
pathlib.Path('invocation.json').write_text(json.dumps(sys.argv[1:]))
url = sys.argv[-1]
if 'ZbCdEf_12-3' in url:
    pathlib.Path('video.mp4.part').write_bytes(b'partial')
    print('download: 10.0%', flush=True)
    time.sleep(20)
elif 'YbCdEf_12-3' in url:
    pathlib.Path('video.mp4.part').write_bytes(b'partial')
    print('ERROR: Sign in to confirm private URL https://example.invalid/SECRET', file=sys.stderr, flush=True)
    sys.exit(1)
elif 'XbCdEf_12-3' in url:
    sys.exit(0)
else:
    print('download: 25.0%', flush=True)
    print('x' * 200000, flush=True)
    pathlib.Path('video.mp4').write_bytes(b'fake complete video for controller checks')
    print('download: 100.0%', flush=True)
""")
fake.chmod(0o755)
harness = r'''
import Foundation
import PlayerCore

@MainActor final class CaptionGate {
    var ready = false
    var snapshot: SubtitleExportSnapshot?
    var cancelled = false
    func resolve() async -> SubtitleExportSnapshot? {
        while !ready && !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(5)) } catch { break }
        }
        if Task.isCancelled { cancelled = true; return nil }
        return snapshot
    }
}

@main @MainActor struct VideoSaveChecks {
    static var assertions = 0
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        assertions += 1
        if !value() { throw NSError(domain: "VideoSaveChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func settle(_ controller: VideoSaveController) async throws {
        let end = Date().addingTimeInterval(8)
        while controller.isSaving && Date() < end { try await Task.sleep(for: .milliseconds(10)) }
        try expect(!controller.isSaving, "save did not settle")
    }
    static func until(_ condition: () -> Bool) async throws {
        let end = Date().addingTimeInterval(8)
        while !condition() && Date() < end { try await Task.sleep(for: .milliseconds(10)) }
        try expect(condition(), "save did not reach expected stage")
    }
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let helper = URL(fileURLWithPath: CommandLine.arguments[2])
        let parent = root.appendingPathComponent("Saves with spaces & percent%", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("original.mp4")
        let original = Data(repeating: 37, count: 2_000_000)
        try original.write(to: source, options: .withoutOverwriting)
        let first = SubtitleTrack(cues: [.init(id: 1, start: 1, end: 3, text: "First track.")])
        let second = SubtitleTrack(cues: [.init(id: 1, start: 1, end: 3, text: "繁體字幕。")])
        let snapshot = SubtitleExportSnapshot(primary: first, secondary: second,
            primaryOffset: 0.75, secondaryOffset: 1.5, sourceURLs: [source], suggestedName: "test.bilingual.srt", isLive: false)
        let saver = VideoSaveController(helperURL: helper)
        try expect(!saver.isSaving && saver.outputDirectory == nil, "construction started saving")
        let link = try YouTubeLink.parse("AbCdEf_12-3")
        var results: [URL] = []
        saver.save(link: link, snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try expect(saver.isSaving, "save is not synchronously busy")
        saver.save(link: link, snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try await settle(saver)
        try expect(results.count == 1 && saver.error == nil && saver.progress == 1, "save completion failed or duplicate action started second save")
        let firstFolder = results[0]
        try expect(!firstFolder.lastPathComponent.hasSuffix(".partial"), "successful folder still partial")
        try expect(firstFolder.deletingLastPathComponent() == parent, "saved outside selected folder")
        let names = Set(try FileManager.default.contentsOfDirectory(atPath: firstFolder.path))
        for name in ["video.mp4", "video.primary.srt", "video.secondary.srt", "subtitles.bilingual.srt", "subtitles.bilingual.txt", "subtitles.bilingual.docx"] {
            try expect(names.contains(name), "missing output " + name)
        }
        let p = try SubtitleParser.parse(String(contentsOf: firstFolder.appendingPathComponent("video.primary.srt"), encoding: .utf8), fileExtension: "srt")
        let s = try SubtitleParser.parse(String(contentsOf: firstFolder.appendingPathComponent("video.secondary.srt"), encoding: .utf8), fileExtension: "srt")
        try expect(p.first?.start == 1.75 && p.first?.end == 3.75, "first offset not applied exactly once")
        try expect(s.first?.start == 2.5 && s.first?.end == 4.5, "second offset not applied exactly once")
        let txt = try String(contentsOf: firstFolder.appendingPathComponent("subtitles.bilingual.txt"), encoding: .utf8)
        try expect(txt.contains("First track.") && txt.contains("繁體字幕。"), "reading export lost a track")
        let docx = try Data(contentsOf: firstFolder.appendingPathComponent("subtitles.bilingual.docx"))
        try expect(docx.starts(with: [0x50, 0x4b, 0x03, 0x04]), "Word output is not DOCX")
        let args = try JSONSerialization.jsonObject(with: Data(contentsOf: firstFolder.appendingPathComponent("invocation.json"))) as! [String]
        try expect(args == VideoSavePlan.downloadArguments(for: link), "helper got unsafe or unexpected arguments")
        try expect(try Data(contentsOf: source) == original, "source changed")

        saver.save(link: link, snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try await settle(saver)
        try expect(results.count == 2 && results[0] != results[1], "second save reused destination")
        try expect(FileManager.default.fileExists(atPath: firstFolder.appendingPathComponent("video.mp4").path), "second save damaged first save")

        saver.save(link: try YouTubeLink.parse("YbCdEf_12-3"), snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try await settle(saver)
        try expect(results.count == 2 && saver.error != nil, "failed helper published success")
        try expect(saver.status.english.contains("sign-in") && !saver.status.english.contains("SECRET"), "failure leaks raw diagnostic or hides reason")
        let failed = saver.outputDirectory!
        try expect(failed.lastPathComponent.hasSuffix(".partial"), "failed folder is not partial")
        try expect(try Data(contentsOf: failed.appendingPathComponent("video.mp4.part")) == Data("partial".utf8),
                   "failure discarded files already produced in the partial directory")

        saver.save(link: try YouTubeLink.parse("XbCdEf_12-3"), snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try await settle(saver)
        try expect(results.count == 2 && saver.error?.english.contains("complete video") == true, "zero exit without video counted as success")

        saver.save(link: try YouTubeLink.parse("ZbCdEf_12-3"), snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try await until { saver.progress != nil }
        let cancelled = saver.outputDirectory!
        saver.cancel()
        try expect(!saver.isSaving && saver.status.english.contains("cancelled"), "cancel did not update state")
        saver.save(link: link, snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try await settle(saver)
        try await Task.sleep(for: .milliseconds(250))
        try expect(results.count == 3 && saver.error == nil && saver.status.english.contains("saved"), "cancelled old save changed current state")
        try expect(cancelled.lastPathComponent.hasSuffix(".partial") && FileManager.default.fileExists(atPath: cancelled.path), "cancel discarded partial folder")

        saver.saveLocal(mediaURL: source, snapshot: nil, destinationDirectory: parent) { results.append($0) }
        try await settle(saver)
        try expect(results.count == 4 && saver.error == nil, "local video-only save failed")
        let local = results.last!
        try expect(try Data(contentsOf: local.appendingPathComponent("video.mp4")) == original, "local copy changed bytes")
        try expect(Set(try FileManager.default.contentsOfDirectory(atPath: local.path)) == ["video.mp4"], "video-only copy created unrelated files")
        saver.saveLocal(mediaURL: source, snapshot: snapshot, destinationDirectory: parent) { results.append($0) }
        try await settle(saver)
        try expect(results.count == 5 && saver.error == nil, "local video and captions save failed")
        try expect(try Data(contentsOf: source) == original, "source altered after local copy")

        saver.save(link: link, snapshot: snapshot, destinationDirectory: source) { results.append($0) }
        try await settle(saver)
        try expect(results.count == 5 && saver.error != nil && saver.outputDirectory == nil, "file accepted as destination directory")

        let deferredSaver = VideoSaveController(helperURL: helper)
        var deferredResults: [URL] = []
        deferredSaver.save(link: link, snapshot: nil, destinationDirectory: parent) { deferredResults.append($0) }
        try await settle(deferredSaver)
        try expect(deferredResults.count == 1 && deferredSaver.error == nil
                   && deferredSaver.status.english == "Video saved. Subtitles were unavailable.",
                   "YouTube video-only save failed or claimed subtitles were saved")
        try expect(Set(try FileManager.default.contentsOfDirectory(atPath: deferredResults[0].path)) == ["video.mp4", "invocation.json"],
                   "video-only save fabricated subtitle files")

        let gate = CaptionGate()
        gate.snapshot = snapshot
        deferredSaver.save(link: link, subtitleProvider: { await gate.resolve() }, destinationDirectory: parent) { deferredResults.append($0) }
        try await until { deferredSaver.status.english == "Video ready. Finishing subtitles…" }
        let pendingFolder = deferredSaver.outputDirectory!
        try expect(deferredSaver.isSaving && deferredResults.count == 1 && pendingFolder.lastPathComponent.hasSuffix(".partial"),
                   "media completion prematurely finalized an unfinished caption request")
        try expect(FileManager.default.fileExists(atPath: pendingFolder.appendingPathComponent("video.mp4").path),
                   "pending subtitle retrieval prevented the media transfer from starting")
        try expect(!FileManager.default.fileExists(atPath: pendingFolder.appendingPathComponent("video.primary.srt").path),
                   "pending provider published a premature first-track snapshot")
        gate.ready = true
        try await settle(deferredSaver)
        try expect(deferredResults.count == 2 && deferredSaver.error == nil && deferredSaver.status.english == "Video and synchronized subtitles saved.",
                   "settled subtitle pair did not finalize the save")
        let deferredFolder = deferredResults.last!
        let deferredFirst = try SubtitleParser.parse(String(contentsOf: deferredFolder.appendingPathComponent("video.primary.srt"), encoding: .utf8), fileExtension: "srt")
        let deferredSecond = try SubtitleParser.parse(String(contentsOf: deferredFolder.appendingPathComponent("video.secondary.srt"), encoding: .utf8), fileExtension: "srt")
        try expect(deferredFirst.first?.start == 1.75 && deferredSecond.first?.start == 2.5,
                   "deferred subtitle pickup omitted a track or applied offsets incorrectly")

        let cancelledGate = CaptionGate()
        cancelledGate.snapshot = snapshot
        deferredSaver.save(link: link, subtitleProvider: { await cancelledGate.resolve() }, destinationDirectory: parent) { deferredResults.append($0) }
        try await until { deferredSaver.status.english == "Video ready. Finishing subtitles…" }
        let cancelledSubtitleFolder = deferredSaver.outputDirectory!
        deferredSaver.cancel()
        try expect(!deferredSaver.isSaving && deferredSaver.status.english.contains("cancelled"),
                   "cancel during subtitle finalization did not immediately update the UI")
        deferredSaver.save(link: link, snapshot: nil, destinationDirectory: parent) { deferredResults.append($0) }
        try await settle(deferredSaver)
        try await until { cancelledGate.cancelled }
        cancelledGate.ready = true
        try expect(deferredResults.count == 3 && deferredSaver.status.english == "Video saved. Subtitles were unavailable.",
                   "cancelled old caption provider changed a newer video save")
        try expect(FileManager.default.fileExists(atPath: cancelledSubtitleFolder.appendingPathComponent("video.mp4").path)
                   && !FileManager.default.fileExists(atPath: cancelledSubtitleFolder.appendingPathComponent("video.secondary.srt").path),
                   "subtitle-stage cancellation deleted downloaded media or installed stale subtitle content")

        let partial = SubtitleExportSnapshot(primary: first, secondary: SubtitleTrack(cues: []),
            primaryOffset: 0, secondaryOffset: 0, sourceURLs: [], suggestedName: "subtitles.bilingual.srt", isLive: false)
        deferredSaver.save(link: link, snapshot: partial, destinationDirectory: parent) { deferredResults.append($0) }
        try await settle(deferredSaver)
        try expect(deferredResults.count == 4 && deferredSaver.status.english.contains("One subtitle track was unavailable"),
                   "partial subtitle save hid the missing track")
        print("VIDEO SAVE CHECKS: \(assertions) assertions passed; fake helper only, no network or real YouTube media download")
    }
}
'''
# Use a throwing autoclosure for file comparison assertions.
harness = harness.replace("@autoclosure () -> Bool", "@autoclosure () throws -> Bool").replace("if !value()", "if try !value()")
(work / "SaveChecks.swift").write_text(harness)
core = sorted((root / "Sources/PlayerCore").glob("*.swift"))
subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-emit-library", "-emit-module",
    "-module-name", "PlayerCore", "-emit-module-path", str(work / "PlayerCore.swiftmodule"),
    *map(str, core), "-o", str(work / "libPlayerCore.dylib"),
    "-Xlinker", "-install_name", "-Xlinker", "@rpath/libPlayerCore.dylib"], check=True)
subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-I", str(work), "-L", str(work), "-lPlayerCore",
    str(root / "Sources/AxonTube/SubtitleExportSnapshot.swift"), str(root / "Sources/AxonTube/VideoSaveController.swift"),
    str(work / "SaveChecks.swift"), "-Xlinker", "-rpath", "-Xlinker", str(work), "-o", str(work / "checks")], check=True)
subprocess.run([str(work / "checks"), str(work), str(fake)], check=True)
