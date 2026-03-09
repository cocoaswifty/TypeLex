import Foundation
import XCTest
@testable import TypeLex

final class WordRepositoryTests: XCTestCase {
    private var tempDirectory: URL!
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        suiteName = "TypeLexTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        if let suiteName {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        userDefaults = nil
        tempDirectory = nil
        suiteName = nil
    }

    func testRepositoryPersistsWordsToCSVAndReloads() throws {
        let repository = makeRepository(performStartupTasks: false)
        repository.createNewBook(name: "Default")

        let entry = WordEntry(
            word: "apple",
            phonetic: "/ˈæp.əl/",
            translation: "蘋果",
            meaning: "Apple is a fruit.",
            meaningTranslation: "蘋果是一種水果。",
            example: "An apple a day keeps the doctor away.",
            exampleTranslation: "一天一蘋果，醫生遠離我。",
            imageName: nil,
            localImagePath: nil,
            soundPath: nil,
            soundMeaningPath: nil,
            soundExamplePath: nil,
            isFavorite: true,
            mistakeCount: 1,
            reviewStage: 2,
            lastReviewedAt: Date(timeIntervalSince1970: 1_700_000_000),
            nextReviewAt: Date(timeIntervalSince1970: 1_700_000_600)
        )

        repository.addWord(entry)

        let reloaded = makeRepository()
        reloaded.loadBook(name: "Default")

        XCTAssertEqual(reloaded.words.count, 1)
        XCTAssertEqual(reloaded.words[0].word, "apple")
        XCTAssertEqual(reloaded.words[0].translation, "蘋果")
        XCTAssertEqual(reloaded.words[0].reviewStage, 2)
        XCTAssertEqual(reloaded.words[0].mistakeCount, 1)
    }

    func testStartupMigratesRootCSVIntoBookFolder() throws {
        let rootCSV = tempDirectory.appendingPathComponent("Default.csv")
        let legacyCSV = """
        \(CSVHelper.header)
        apple,/ˈæp.əl/,蘋果,Apple is a fruit.,蘋果是一種水果。,An apple a day.,一天一蘋果。,,apple.png,apple.mp3,,,false,0,0,,
        """
        try legacyCSV.write(to: rootCSV, atomically: true, encoding: .utf8)
        try Data("img".utf8).write(to: tempDirectory.appendingPathComponent("apple.png"))
        try Data("audio".utf8).write(to: tempDirectory.appendingPathComponent("apple.mp3"))

        let repository = makeRepository()

        let bookFolder = tempDirectory.appendingPathComponent("Default")
        let migratedCSV = bookFolder.appendingPathComponent("Default.csv")
        let migratedImage = bookFolder.appendingPathComponent("media/apple.png")
        let migratedAudio = bookFolder.appendingPathComponent("media/apple.mp3")

        XCTAssertFalse(FileManager.default.fileExists(atPath: rootCSV.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedCSV.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedImage.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedAudio.path))
        XCTAssertEqual(repository.words.first?.localImagePath, "media/apple.png")
        XCTAssertEqual(repository.words.first?.soundPath, "media/apple.mp3")
    }

    func testRecordPracticeResultUpdatesForSuccessAndMistake() throws {
        let repository = makeRepository(performStartupTasks: false)
        repository.createNewBook(name: "Default")
        repository.addWord(
            WordEntry(
                word: "apple",
                phonetic: nil,
                translation: "蘋果",
                meaning: "Apple is a fruit.",
                meaningTranslation: nil,
                example: nil,
                exampleTranslation: nil,
                imageName: nil,
                localImagePath: nil,
                soundPath: nil,
                soundMeaningPath: nil,
                soundExamplePath: nil,
                isFavorite: false,
                mistakeCount: 0,
                reviewStage: 0,
                lastReviewedAt: nil,
                nextReviewAt: nil
            )
        )

        let firstReview = Date(timeIntervalSince1970: 1_700_000_000)
        repository.recordPracticeResult(for: "apple", errorCount: 0, reviewedAt: firstReview)

        XCTAssertEqual(repository.words[0].reviewStage, 1)
        XCTAssertEqual(repository.words[0].nextReviewAt?.timeIntervalSince1970, firstReview.addingTimeInterval(5 * 60).timeIntervalSince1970, accuracy: 1)

        let secondReview = firstReview.addingTimeInterval(60)
        repository.recordPracticeResult(for: "apple", errorCount: 2, reviewedAt: secondReview)

        XCTAssertEqual(repository.words[0].reviewStage, 0)
        XCTAssertEqual(repository.words[0].mistakeCount, 2)
        XCTAssertEqual(repository.words[0].nextReviewAt?.timeIntervalSince1970, secondReview.addingTimeInterval(2 * 60).timeIntervalSince1970, accuracy: 1)
    }

    private func makeRepository(performStartupTasks: Bool = true) -> WordRepository {
        WordRepository(
            storageDirectoryOverride: tempDirectory,
            userDefaults: userDefaults,
            fileManager: .default,
            performStartupTasks: performStartupTasks
        )
    }
}
