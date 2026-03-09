import Foundation
import OSLog

extension WordRepository {
    /// 儲存全新匯入的單字（含圖片處理）
    func saveNewWord(entry: WordEntry, imageData: Data?) {
        var newEntry = entry

        if let data = imageData {
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "\(entry.word)_\(timestamp).png"
            let fileURL = currentMediaFolder.appendingPathComponent(fileName)

            do {
                if !fileManager.fileExists(atPath: currentMediaFolder.path) {
                    try fileManager.createDirectory(at: currentMediaFolder, withIntermediateDirectories: true)
                }
                try data.write(to: fileURL)
                newEntry.localImagePath = "media/\(fileName)"
            } catch {
                AppLogger.repository.error("Failed to save word image: \(error.localizedDescription)")
            }
        }

        addWord(newEntry)
    }

    /// 新增或更新單字
    func addWord(_ word: WordEntry) {
        applyWordsMutation {
            if let index = words.firstIndex(where: { $0.word.lowercased() == word.word.lowercased() }) {
                words[index] = mergeUserProgress(from: words[index], into: word)
            } else {
                words.append(word)
            }
        }
    }

    /// 更新單字圖片
    func updateImage(for wordID: String, imageData: Data) {
        guard let index = words.firstIndex(where: { $0.id == wordID }) else { return }

        if let oldPath = words[index].localImagePath {
            let oldURL = resolveFileURL(for: oldPath)
            try? fileManager.removeItem(at: oldURL)
        }

        let newFileName = "\(words[index].word)_\(Int(Date().timeIntervalSince1970)).png"
        let newURL = currentMediaFolder.appendingPathComponent(newFileName)

        do {
            if !fileManager.fileExists(atPath: currentMediaFolder.path) {
                try fileManager.createDirectory(at: currentMediaFolder, withIntermediateDirectories: true)
            }
            try imageData.write(to: newURL)
            words[index].localImagePath = "media/\(newFileName)"
            saveWords()
        } catch {
            AppLogger.repository.error("Failed to update image: \(error.localizedDescription)")
        }
    }

    /// 更新單字文字資訊
    func updateWordInfo(for wordID: String, phonetic: String, translation: String?, meaning: String, meaningTranslation: String?, example: String, exampleTranslation: String, soundPath: String? = nil, soundMeaningPath: String? = nil, soundExamplePath: String? = nil) {
        guard words.contains(where: { $0.id == wordID }) else { return }

        applyWordsMutation {
            guard let index = words.firstIndex(where: { $0.id == wordID }) else { return }

            words[index].phonetic = phonetic
            words[index].translation = translation
            words[index].meaning = meaning
            words[index].meaningTranslation = meaningTranslation
            words[index].example = example
            words[index].exampleTranslation = exampleTranslation

            if let soundPath { words[index].soundPath = soundPath }
            if let soundMeaningPath { words[index].soundMeaningPath = soundMeaningPath }
            if let soundExamplePath { words[index].soundExamplePath = soundExamplePath }
        }
    }

    /// Import Library from folder
    func importLibrary(from folderURL: URL) throws {
        if !fileManager.fileExists(atPath: currentMediaFolder.path) {
            try fileManager.createDirectory(at: currentMediaFolder, withIntermediateDirectories: true)
        }

        let newWords = try LibraryImporter.importLibrary(from: folderURL, to: currentMediaFolder)

        applyWordsMutation {
            for var word in newWords {
                if let path = word.localImagePath, !path.isEmpty { word.localImagePath = "media/\(path)" }
                if let path = word.soundPath, !path.isEmpty { word.soundPath = "media/\(path)" }
                if let path = word.soundMeaningPath, !path.isEmpty { word.soundMeaningPath = "media/\(path)" }
                if let path = word.soundExamplePath, !path.isEmpty { word.soundExamplePath = "media/\(path)" }

                if let index = words.firstIndex(where: { $0.word.lowercased() == word.word.lowercased() }) {
                    words[index] = mergeUserProgress(from: words[index], into: word)
                } else {
                    words.append(word)
                }
            }
        }
    }

    /// 切換收藏狀態
    func toggleFavorite(for wordID: String) {
        guard words.contains(where: { $0.id == wordID }) else { return }
        applyWordsMutation {
            if let index = words.firstIndex(where: { $0.id == wordID }) {
                words[index].isFavorite.toggle()
            }
        }
    }

    /// 批量設定收藏狀態
    func setFavorite(_ isFavorite: Bool, for wordIDs: Set<String>) {
        guard !wordIDs.isEmpty else { return }
        let hasChanges = words.contains { wordIDs.contains($0.id) && $0.isFavorite != isFavorite }
        guard hasChanges else { return }

        applyWordsMutation {
            for index in words.indices where wordIDs.contains(words[index].id) {
                if words[index].isFavorite != isFavorite {
                    words[index].isFavorite = isFavorite
                }
            }
        }
    }

    /// 根據答題結果更新遺忘曲線排程與錯誤統計
    func recordPracticeResult(for wordID: String, errorCount: Int, reviewedAt: Date = Date()) {
        applyRepositoryStateMutation {
            if let index = words.firstIndex(where: { $0.id == wordID }) {
                let existingWord = words[index]
                let wasNewWord = existingWord.lastReviewedAt == nil || existingWord.nextReviewAt == nil
                let wasOverdue = (existingWord.nextReviewAt ?? .distantFuture) <= reviewedAt && existingWord.nextReviewAt != nil

                if errorCount > 0 {
                    let currentMistakes = words[index].mistakeCount ?? 0
                    words[index].mistakeCount = currentMistakes + errorCount
                }

                let currentStage = max(0, words[index].reviewStage ?? 0)
                let nextStage: Int
                let nextInterval: TimeInterval

                if errorCount == 0 {
                    nextStage = min(currentStage + 1, Self.forgettingCurveIntervals.count)
                    let intervalIndex = max(0, nextStage - 1)
                    nextInterval = Self.forgettingCurveIntervals[intervalIndex]
                } else {
                    nextStage = max(currentStage - 1, 0)
                    nextInterval = Self.retryInterval(for: errorCount)
                }

                words[index].reviewStage = nextStage
                words[index].lastReviewedAt = reviewedAt
                words[index].nextReviewAt = reviewedAt.addingTimeInterval(nextInterval)

                reviewEvents.append(
                    ReviewEvent(
                        wordID: existingWord.id,
                        word: existingWord.word,
                        reviewedAt: reviewedAt,
                        errorCount: errorCount,
                        wasSuccessful: errorCount == 0,
                        resultingReviewStage: nextStage,
                        wasNewWord: wasNewWord,
                        wasOverdue: wasOverdue
                    )
                )
            }
        }
    }

    /// 批量刪除單字
    func deleteWords(at offsets: IndexSet) {
        let ids = Set(offsets.compactMap { words.indices.contains($0) ? words[$0].id : nil })
        deleteWords(withIDs: ids)
    }

    /// 批量刪除單字
    func deleteWords(withIDs wordIDs: Set<String>) {
        guard !wordIDs.isEmpty else { return }
        removeWordsFromCurrentBook(withIDs: wordIDs, deleteMedia: true)
    }

    /// 批量將單字移動到另一個單詞本
    func moveWords(withIDs wordIDs: Set<String>, toBookNamed destinationBookName: String) throws {
        guard !wordIDs.isEmpty, destinationBookName != currentBookName else { return }

        if !availableBooks.contains(destinationBookName) {
            _ = try ensureBookExists(named: destinationBookName)
        }

        var destinationWords = try storageSupport.loadWords(fromBookNamed: destinationBookName)
        let movingWords = words.filter { wordIDs.contains($0.id) }

        for word in movingWords {
            try storageSupport.copyMediaAssets(for: word, fromBookNamed: currentBookName, toBookNamed: destinationBookName)

            if let index = destinationWords.firstIndex(where: { $0.word.lowercased() == word.word.lowercased() }) {
                destinationWords[index] = mergeUserProgress(from: destinationWords[index], into: word)
            } else {
                destinationWords.append(word)
            }
        }

        try storageSupport.saveWords(destinationWords, toBookNamed: destinationBookName)
        removeWordsFromCurrentBook(withIDs: wordIDs, deleteMedia: false)
        refreshAvailableBooks()
    }

    /// 批量重置複習進度與錯誤統計
    func resetReviewProgress(for wordIDs: Set<String>) {
        guard !wordIDs.isEmpty else { return }

        applyWordsMutation {
            for index in words.indices where wordIDs.contains(words[index].id) {
                words[index].mistakeCount = 0
                words[index].reviewStage = 0
                words[index].lastReviewedAt = nil
                words[index].nextReviewAt = nil
            }
        }
    }

    func removeWordsFromCurrentBook(withIDs wordIDs: Set<String>, deleteMedia: Bool) {
        guard !wordIDs.isEmpty else { return }

        if deleteMedia {
            for entry in words where wordIDs.contains(entry.id) {
                storageSupport.removeMediaAssets(for: entry, inBookNamed: currentBookName)
            }
        }

        applyWordsMutation {
            words.removeAll { wordIDs.contains($0.id) }
        }
    }

    func mergeUserProgress(from existing: WordEntry, into incoming: WordEntry) -> WordEntry {
        var merged = incoming
        merged.isFavorite = existing.isFavorite || incoming.isFavorite
        merged.mistakeCount = max(existing.mistakeCount ?? 0, incoming.mistakeCount ?? 0)
        merged.reviewStage = max(existing.reviewStage ?? 0, incoming.reviewStage ?? 0)
        merged.lastReviewedAt = incoming.lastReviewedAt ?? existing.lastReviewedAt
        merged.nextReviewAt = incoming.nextReviewAt ?? existing.nextReviewAt
        return merged
    }

    static func retryInterval(for errorCount: Int) -> TimeInterval {
        switch errorCount {
        case 3...:
            return 60
        case 2:
            return 2 * 60
        default:
            return 5 * 60
        }
    }
}
