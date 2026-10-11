import XCTest
@testable import PlayerCore

final class LiveTranscriptTests: XCTestCase {
    func testPartialRevisionAndFinalization() {
        var transcript = LiveTranscript()
        transcript.update(text: "Hello", start: 0, end: 1, isFinal: false, finalizedThrough: 0)
        let id = transcript.captions[0].id
        transcript.update(text: "Hello world", start: 0, end: 2, isFinal: false, finalizedThrough: 0)
        XCTAssertEqual(transcript.captions.count, 1)
        XCTAssertEqual(transcript.captions[0].id, id)
        transcript.update(text: "Next", start: 2, end: 3, isFinal: false, finalizedThrough: 2)
        XCTAssertTrue(transcript.captions[0].isFinal)
        XCTAssertEqual(transcript.captions[1].isFinal, false)
    }

    func testRetractionAndStaleTranslation() {
        var transcript = LiveTranscript()
        transcript.update(text: "Wrong", start: 1, end: 2, isFinal: false, finalizedThrough: 0)
        let id = transcript.captions[0].id
        transcript.update(text: "Right", start: 1, end: 2, isFinal: true, finalizedThrough: 2)
        transcript.translate(id: id, source: "Wrong", text: "错")
        XCTAssertNil(transcript.captions[0].translation)
        transcript.translate(id: id, source: "Right", text: "对")
        XCTAssertEqual(transcript.captions[0].translation, "对")
        transcript.update(text: "", start: 1, end: 2, isFinal: true, finalizedThrough: 2)
        XCTAssertTrue(transcript.captions.isEmpty)
    }

    func testReplayReplacesOverlappingHistory() {
        var transcript = LiveTranscript()
        transcript.update(text: "First pass", start: 4, end: 6, isFinal: true, finalizedThrough: 6)
        transcript.update(text: "Replay", start: 4, end: 5, isFinal: false, finalizedThrough: 4)
        XCTAssertEqual(transcript.captions.count, 1)
        XCTAssertEqual(transcript.captions[0].text, "Replay")
        transcript.update(text: "invalid", start: .nan, end: 5, isFinal: true, finalizedThrough: 5)
        XCTAssertEqual(transcript.captions.count, 1)
    }
}
