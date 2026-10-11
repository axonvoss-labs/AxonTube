import Foundation
import XCTest
@testable import PlayerCore

final class YouTubeLinkTests: XCTestCase {
    private let videoID = "AbCdEf_12-3"

    func testOfficialHostsAndCommonPaths() throws {
        let links = [
            "https://youtube.com/watch?v=\(videoID)",
            "https://www.youtube.com/watch/?v=\(videoID)",
            "https://m.youtube.com/watch?v=\(videoID)",
            "https://music.youtube.com/watch?v=\(videoID)",
            "https://youtu.be/\(videoID)",
            "https://www.youtu.be/\(videoID)/",
            "https://www.youtube.com/shorts/\(videoID)",
            "https://www.youtube.com/live/\(videoID)",
            "https://www.youtube.com/embed/\(videoID)",
            "https://youtube-nocookie.com/embed/\(videoID)",
            "https://www.youtube-nocookie.com/embed/\(videoID)",
            "HTTP://WWW.YOUTUBE.COM:80/watch?v=\(videoID)",
            "https://www.youtube.com:443/watch?v=\(videoID)"
        ]
        for raw in links {
            let link = try YouTubeLink.parse(raw)
            XCTAssertEqual(link.videoID, videoID, raw)
            XCTAssertEqual(link.startTime, 0, raw)
            XCTAssertEqual(link.canonicalURL.absoluteString, "https://www.youtube.com/watch?v=\(videoID)", raw)
        }
    }

    func testBareIDAndSchemeLessLinks() throws {
        for raw in [videoID, "  \(videoID)\n", "youtu.be/\(videoID)", "WWW.YOUTUBE.COM/watch?v=\(videoID)", "m.youtube.com:443/shorts/\(videoID)"] {
            XCTAssertEqual(try YouTubeLink.parse(raw).videoID, videoID, raw)
        }
    }

    func testSecondsDurationsAndFragmentTimes() throws {
        let values: [(String, Double)] = [
            ("t=90", 90), ("start=90", 90), ("t=1h2m3s", 3723),
            ("t=2m", 120), ("t=90s", 90), ("t=1h", 3600),
            ("t=01H02M03S", 3723), ("t=1m2.5s", 62.5),
            ("start=0", 0), ("t=001.250", 1.25), ("t=31536000", 31_536_000)
        ]
        for (query, expected) in values {
            XCTAssertEqual(try YouTubeLink.parse("https://youtu.be/\(videoID)?\(query)").startTime, expected, query)
        }
        XCTAssertEqual(try YouTubeLink.parse("https://youtu.be/\(videoID)#t=2m3s").startTime, 123)
        XCTAssertEqual(try YouTubeLink.parse("https://youtu.be/\(videoID)?t=1.25").canonicalURL.absoluteString,
                       "https://www.youtube.com/watch?v=\(videoID)&t=1.25")
    }

    func testTrackingAndUnrelatedQueryDataAreDiscarded() throws {
        let link = try YouTubeLink.parse("https://youtu.be/\(videoID)?si=private-share-token&feature=shared&list=private-list&t=1m30s#ignored")
        XCTAssertEqual(link.canonicalURL.absoluteString, "https://www.youtube.com/watch?v=\(videoID)&t=90")
        let zero = try YouTubeLink.parse("https://www.youtube.com/watch?v=\(videoID)&t=0&redirect=https%3A%2F%2Fevil.example")
        XCTAssertEqual(zero.canonicalURL.absoluteString, "https://www.youtube.com/watch?v=\(videoID)")
    }

    func testRejectsUntrustedDomainsSchemesCredentialsAndPorts() {
        let invalid = [
            "https://evil.example/watch?v=\(videoID)",
            "https://youtube.com.evil.example/watch?v=\(videoID)",
            "https://evilyoutube.com/watch?v=\(videoID)",
            "https://youtube.com@evil.example/watch?v=\(videoID)",
            "https://evil.example@youtube.com/watch?v=\(videoID)",
            "https://user:password@www.youtube.com/watch?v=\(videoID)",
            "https://@www.youtube.com/watch?v=\(videoID)",
            "https://www.youtube.com:9507/watch?v=\(videoID)",
            "https://www.youtube.com:80/watch?v=\(videoID)",
            "http://www.youtube.com:443/watch?v=\(videoID)",
            "file://www.youtube.com/watch?v=\(videoID)",
            "javascript:alert('youtube.com')",
            "data:text/html,https://youtu.be/\(videoID)",
            "//www.youtube.com/watch?v=\(videoID)",
            "https://%77ww.youtube.com/watch?v=\(videoID)",
            "https://www.youtube.com./watch?v=\(videoID)",
            "https://www.yоutube.com/watch?v=\(videoID)", // Cyrillic o.
            "https://www.youtube.com\\@evil.example/watch?v=\(videoID)",
            "https://www.youtube.com/\nwatch?v=\(videoID)",
            "https://www.youtube.com/watch?v=\(videoID)\u{0000}"
        ]
        for raw in invalid { XCTAssertThrowsError(try YouTubeLink.parse(raw), raw) }
    }

    func testRejectsMissingMalformedAndAmbiguousVideoIDs() {
        let invalid = [
            "", "  \n", "https://www.youtube.com", "https://www.youtube.com/",
            "https://www.youtube.com/watch", "https://www.youtube.com/watch?v=",
            "https://www.youtube.com/playlist?list=\(videoID)",
            "https://www.youtube.com/watch?v=1234567890", "https://www.youtube.com/watch?v=123456789012",
            "https://youtu.be/abcdefghij!", "https://youtu.be/abcd中文efghi",
            "https://youtu.be/\(videoID)/extra", "https://www.youtube.com//shorts/\(videoID)",
            "https://www.youtube.com/embed%2F\(videoID)",
            "https://www.youtube.com/watch?v=\(videoID)&v=\(videoID)",
            "https://youtu.be/\(videoID)?v=ZbCdEf_12-3",
            String(repeating: "a", count: 4097)
        ]
        for raw in invalid { XCTAssertThrowsError(try YouTubeLink.parse(raw), raw) }
    }

    func testRejectsInvalidNegativeNonfiniteOrAmbiguousTimes() {
        let invalid = ["", "-1", "-0", "NaN", "Infinity", "1e20", "1:30", "1m2h", "1s2s", "h", ".5", "1.", "31536001", "9007199254740992", "1s%0A", "1%0D", "%2B1", String(repeating: "9", count: 129)]
        for value in invalid {
            XCTAssertThrowsError(try YouTubeLink.parse("https://youtu.be/\(videoID)?t=\(value)"), value)
        }
        for suffix in ["?t", "?t=1&t=1", "?t=1&start=1", "?start=1&start=2", "?t=1#t=2"] {
            XCTAssertThrowsError(try YouTubeLink.parse("https://youtu.be/\(videoID)\(suffix)"), suffix)
        }
    }

    func testErrorsProvideGuidanceInBothLanguages() {
        XCTAssertThrowsError(try YouTubeLink.parse("https://example.com/watch?v=\(videoID)")) { error in
            XCTAssertEqual(error as? YouTubeLinkError, .unsupportedHost)
            let guidance = (error as? BilingualError)?.message
            XCTAssertTrue(guidance?.english.contains("official youtube.com or youtu.be") == true)
            XCTAssertTrue(guidance?.chinese.contains("youtube.com 或 youtu.be 的官方") == true)
        }
    }
}
