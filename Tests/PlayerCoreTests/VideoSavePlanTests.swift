import Foundation
import XCTest
@testable import PlayerCore

final class VideoSavePlanTests: XCTestCase {
    func testExplicitSaveUsesCompleteVideoAndSafeFixedOutput() throws {
        let link = try YouTubeLink.parse("https://www.youtube.com/watch?v=AbCdEf_12-3&t=60&private=ignored")
        let args = VideoSavePlan.downloadArguments(for: link)
        XCTAssertEqual(args.last, "https://www.youtube.com/watch?v=AbCdEf_12-3&t=60")
        XCTAssertEqual(args[args.count - 2], "--")
        XCTAssertTrue(args.contains("best[ext=mp4]/best"))
        XCTAssertTrue(args.contains("video.%(ext)s"))
        for required in ["--ignore-config", "--no-plugin-dirs", "--no-cache-dir", "--no-playlist", "--no-overwrites", "--no-continue", "--abort-on-unavailable-fragments"] {
            XCTAssertTrue(args.contains(required), required)
        }
        XCTAssertTrue(!args.contains(where: { $0.contains("cookie") || $0.contains("password") || $0 == "--exec" }))
    }

    func testSaveFolderNamesCannotEscapeDestination() {
        for value in ["../outside/file", "/absolute/path", "..\\..\\source", "\n\0hidden", "..", "", String(repeating: "繁體字幕", count: 200)] {
            let result = VideoSavePlan.safeFolderName(value)
            XCTAssertTrue(!result.isEmpty)
            XCTAssertTrue(!result.hasPrefix("."))
            XCTAssertTrue(!result.contains("/") && !result.contains("\\") && !result.contains("\n") && !result.contains("\0"))
            XCTAssertTrue(result.utf8.count <= 100)
        }
    }

    func testSaveProgressRejectsRawDiagnosticsAndNonfiniteValues() {
        XCTAssertEqual(VideoSavePlan.progress(in: "download: 42.5%"), 0.425)
        XCTAssertEqual(VideoSavePlan.progress(in: "download:100.0%\r"), 1)
        for line in ["filename100%", "download:NaN%", "download:101%", "download:-1%", "download:50", "https://signed-url"] {
            XCTAssertNil(VideoSavePlan.progress(in: line))
        }
    }
}
