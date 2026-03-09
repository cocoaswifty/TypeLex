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

    func testAddWordMergesExistingUserProgress() throws {
        let repository = makeRepository(performStartupTasks: false)
        repository.createNewBook(name: "Default")

        repository.addWord(
            WordEntry(
                word: "apple",
                phonetic: nil,
                translation: "舊翻譯",
                meaning: "Old meaning.",
                meaningTranslation: nil,
                example: nil,
                exampleTranslation: nil,
                imageName: nil,
                localImagePath: nil,
                soundPath: nil,
                soundMeaningPath: nil,
                soundExamplePath: nil,
                isFavorite: true,
                mistakeCount: 3,
                reviewStage: 5,
                lastReviewedAt: Date(timeIntervalSince1970: 1_700_000_000),
                nextReviewAt: Date(timeIntervalSince1970: 1_700_000_900)
            )
        )

        repository.addWord(
            WordEntry(
                word: "apple",
                phonetic: "/ˈæp.əl/",
                translation: "新翻譯",
                meaning: "New meaning.",
                meaningTranslation: "新的意思",
                example: "A new example.",
                exampleTranslation: "新的例句。",
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

        XCTAssertEqual(repository.words.count, 1)
        XCTAssertEqual(repository.words[0].translation, "新翻譯")
        XCTAssertEqual(repository.words[0].meaning, "New meaning.")
        XCTAssertTrue(repository.words[0].isFavorite)
        XCTAssertEqual(repository.words[0].mistakeCount, 3)
        XCTAssertEqual(repository.words[0].reviewStage, 5)
        XCTAssertEqual(repository.words[0].nextReviewAt?.timeIntervalSince1970, 1_700_000_900, accuracy: 1)
    }

    func testImportLibraryRewritesPathsAndMergesExistingProgress() throws {
        let repository = makeRepository(performStartupTasks: false)
        repository.createNewBook(name: "Default")

        repository.addWord(
            WordEntry(
                word: "apple",
                phonetic: nil,
                translation: "蘋果",
                meaning: "Old meaning.",
                meaningTranslation: nil,
                example: nil,
                exampleTranslation: nil,
                imageName: nil,
                localImagePath: nil,
                soundPath: nil,
                soundMeaningPath: nil,
                soundExamplePath: nil,
                isFavorite: true,
                mistakeCount: 4,
                reviewStage: 3,
                lastReviewedAt: Date(timeIntervalSince1970: 1_700_000_000),
                nextReviewAt: Date(timeIntervalSince1970: 1_700_000_600)
            )
        )

        let libraryFolder = tempDirectory.appendingPathComponent("ImportLibrary")
        let mediaFolder = libraryFolder.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)

        let csv = """
        Word,IPA,Translation,Meaning,Meaning_Translation,Example,Example_Translation,Image,Sound
        apple,/ˈæp.əl/,新蘋果,Apple is a fruit.,蘋果是一種水果。,An apple a day.,一天一蘋果。,apple.png,apple.mp3
        berry,/ˈber.i/,莓果,Berry is a small fruit.,莓果是一種小水果。,A berry is sweet.,莓果很甜。,berry.png,berry.mp3
        """
        try csv.write(to: libraryFolder.appendingPathComponent("words.csv"), atomically: true, encoding: .utf8)
        try Data("apple-image".utf8).write(to: mediaFolder.appendingPathComponent("apple.png"))
        try Data("apple-audio".utf8).write(to: mediaFolder.appendingPathComponent("apple.mp3"))
        try Data("berry-image".utf8).write(to: mediaFolder.appendingPathComponent("berry.png"))
        try Data("berry-audio".utf8).write(to: mediaFolder.appendingPathComponent("berry.mp3"))

        try repository.importLibrary(from: libraryFolder)

        XCTAssertEqual(repository.words.count, 2)

        let apple = try XCTUnwrap(repository.words.first(where: { $0.word == "apple" }))
        XCTAssertEqual(apple.translation, "新蘋果")
        XCTAssertEqual(apple.localImagePath, "media/apple.png")
        XCTAssertEqual(apple.soundPath, "media/apple.mp3")
        XCTAssertTrue(apple.isFavorite)
        XCTAssertEqual(apple.mistakeCount, 4)
        XCTAssertEqual(apple.reviewStage, 3)

        let berry = try XCTUnwrap(repository.words.first(where: { $0.word == "berry" }))
        XCTAssertEqual(berry.localImagePath, "media/berry.png")
        XCTAssertEqual(berry.soundPath, "media/berry.mp3")

        XCTAssertTrue(FileManager.default.fileExists(atPath: repository.currentMediaFolder.appendingPathComponent("apple.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repository.currentMediaFolder.appendingPathComponent("berry.mp3").path))
    }

    func testChangeStorageLocationMovesBooksAndReloadsCurrentBook() throws {
        let sourceDirectory = tempDirectory.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

        let destinationDirectory = tempDirectory.appendingPathComponent("Destination")
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let repository = makeRepository(storageDirectory: sourceDirectory, performStartupTasks: false)
        repository.createNewBook(name: "DeckA")
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

        try repository.changeStorageLocation(to: destinationDirectory)

        let movedCSV = destinationDirectory.appendingPathComponent("DeckA/DeckA.csv")
        let oldCSV = sourceDirectory.appendingPathComponent("DeckA/DeckA.csv")

        XCTAssertEqual(repository.currentBookName, "DeckA")
        XCTAssertTrue(FileManager.default.fileExists(atPath: movedCSV.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldCSV.path))
        XCTAssertEqual(repository.words.first?.word, "apple")
    }

    private func makeRepository(storageDirectory: URL? = nil, performStartupTasks: Bool = true) -> WordRepository {
        WordRepository(
            storageDirectoryOverride: storageDirectory ?? tempDirectory,
            userDefaults: userDefaults,
            fileManager: .default,
            performStartupTasks: performStartupTasks
        )
    }
}
