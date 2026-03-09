import XCTest
@testable import TypeLex

final class TypingEngineTests: XCTestCase {
    func testInputTracksProgressAndErrors() {
        var engine = TypingEngine(targetWord: "apple")

        XCTAssertTrue(engine.input(char: "a"))
        XCTAssertFalse(engine.input(char: "x"))

        XCTAssertEqual(engine.cursorIndex, 1)
        XCTAssertEqual(engine.errorCount, 1)
        XCTAssertEqual(engine.typedPrefix, "a")
        XCTAssertEqual(engine.remainingSuffix, "pple")
        XCTAssertTrue(engine.lastInputWasError)
    }

    func testResetClearsStateForNewWord() {
        var engine = TypingEngine(targetWord: "cat")
        _ = engine.input(char: "c")
        _ = engine.input(char: "x")

        engine.reset(newWord: "dog")

        XCTAssertEqual(engine.targetWord, "dog")
        XCTAssertEqual(engine.cursorIndex, 0)
        XCTAssertEqual(engine.errorCount, 0)
        XCTAssertFalse(engine.lastInputWasError)
        XCTAssertEqual(engine.typedPrefix, "")
        XCTAssertEqual(engine.remainingSuffix, "dog")
    }
}
