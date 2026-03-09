import Foundation
import XCTest
@testable import TypeLex

final class CSVHelperTests: XCTestCase {
    func testDecodeLegacyCSVDefaultsReviewMetadata() {
        let legacyHeader = "word,phonetic,translation,meaning,meaningTranslation,example,exampleTranslation,imageName,localImagePath,soundPath,soundMeaningPath,soundExamplePath,isFavorite,mistakeCount"
        let csv = """
        \(legacyHeader)
        apple,/ˈæp.əl/,蘋果,Apple is a fruit.,,An apple a day.,,,,,,true,3
        """

        let words = CSVHelper.decode(csv)

        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].word, "apple")
        XCTAssertEqual(words[0].reviewStage, 0)
        XCTAssertNil(words[0].lastReviewedAt)
        XCTAssertNil(words[0].nextReviewAt)
    }

    func testEncodeDecodePreservesReviewMetadata() {
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let nextReviewAt = reviewedAt.addingTimeInterval(300)
        let word = WordEntry(
            word: "apple",
            phonetic: "/ˈæp.əl/",
            translation: "蘋果",
            meaning: "Apple is a fruit.",
            meaningTranslation: "蘋果是一種水果。",
            example: "An apple a day keeps the doctor away.",
            exampleTranslation: "一天一蘋果，醫生遠離我。",
            imageName: nil,
            localImagePath: "media/apple.png",
            soundPath: "media/apple.mp3",
            soundMeaningPath: nil,
            soundExamplePath: nil,
            isFavorite: true,
            mistakeCount: 2,
            reviewStage: 4,
            lastReviewedAt: reviewedAt,
            nextReviewAt: nextReviewAt
        )

        let encoded = CSVHelper.encode([word])
        let decoded = CSVHelper.decode(encoded)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].reviewStage, 4)
        XCTAssertEqual(decoded[0].mistakeCount, 2)
        XCTAssertEqual(decoded[0].isFavorite, true)
        XCTAssertEqual(decoded[0].lastReviewedAt?.timeIntervalSince1970, reviewedAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(decoded[0].nextReviewAt?.timeIntervalSince1970, nextReviewAt.timeIntervalSince1970, accuracy: 1)
    }
}
