import Foundation
import Combine
import SwiftUI
import Observation

/// 管理單字資料的儲存、持久化與路徑管理
@Observable
class WordRepository {
    var words: [WordEntry] = []
    var currentBookName: String = "Default"
    var availableBooks: [String] = []
    
    private let extensionName = "csv"
    private let defaultBookName = "Default"
    private static let forgettingCurveIntervals: [TimeInterval] = [
        5 * 60,
        30 * 60,
        12 * 60 * 60,
        24 * 60 * 60,
        2 * 24 * 60 * 60,
        4 * 24 * 60 * 60,
        7 * 24 * 60 * 60,
        15 * 24 * 60 * 60,
        30 * 24 * 60 * 60
    ]
    
    private let bookmarkKey = "customStorageBookmark"
    private var customStorageURL: URL?
    
    /// 目前的儲存根目錄 (預設為 ~/Downloads/TypeLexLibrary)
    var storageDirectory: URL {
        if let custom = customStorageURL { return custom }
        
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        return downloads.appendingPathComponent("TypeLexLibrary")
    }
    
    /// 目前單詞本的資料夾路徑 (例如 Documents/Default/)
    var currentBookFolder: URL {
        storageDirectory.appendingPathComponent(currentBookName)
    }
    
    /// 目前單詞本的 CSV 路徑 (例如 Documents/Default/Default.csv)
    var currentBookURL: URL {
        currentBookFolder.appendingPathComponent("\(currentBookName).\(extensionName)")
    }
    
    /// 目前單詞本的媒體資料夾路徑 (例如 Documents/Default/media/)
    var currentMediaFolder: URL {
        currentBookFolder.appendingPathComponent("media")
    }
    
    /// 為了相容性保留的屬性，等同於 currentBookURL.path
    var dataFilePath: String {
        currentBookURL.path
    }
    
    // MARK: - Initialization
    
    init() {
        restoreSecurityScopedAccess()
        
        // 遷移舊版結構
        migrateFileStructure()
        
        // 載入上次使用的單詞本，或是預設本
        let lastBook = UserDefaults.standard.string(forKey: "LastOpenBook") ?? defaultBookName
        loadBook(name: lastBook)
        
        refreshAvailableBooks()
    }

    // MARK: - Path Helpers
    
    /// 取得檔案的完整路徑（相對於當前單詞本）
    /// - Parameter path: 相對路徑 (e.g., "media/image.png")
    /// - Returns: 完整 URL
    func resolveFileURL(for path: String) -> URL {
        // 如果路徑已經是絕對路徑(不建議)，直接回傳
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        
        // 預設相對於當前單詞本資料夾
        return currentBookFolder.appendingPathComponent(path)
    }

    // MARK: - Book Management
    
    /// 刷新可用單詞本列表 (掃描資料夾)
    private func refreshAvailableBooks() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            
            var books: [String] = []
            for url in urls {
                // 必須是資料夾
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    let name = url.lastPathComponent
                    // 檢查裡面是否有同名的 .csv
                    let csvPath = url.appendingPathComponent("\(name).\(extensionName)")
                    if FileManager.default.fileExists(atPath: csvPath.path) {
                        books.append(name)
                    }
                }
            }
            // 如果列表為空，可能還沒遷移完或剛初始化，確保至少有 Default
            self.availableBooks = books.sorted()
        } catch {
            print("❌ Failed to list books: \(error)")
            self.availableBooks = []
        }
    }
    
    /// 切換單詞本
    func loadBook(name: String) {
        let folderURL = storageDirectory.appendingPathComponent(name)
        let fileURL = folderURL.appendingPathComponent("\(name).\(extensionName)")
        
        var shouldCreate = false
        
        // 檢查資料夾與檔案是否存在
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("⚠️ Book \(name) not found at \(fileURL.path).")
            shouldCreate = true
        } else {
            // 檢查檔案大小
            if let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attr[.size] as? UInt64, size == 0 {
                print("⚠️ Book \(name) is empty. Treating as missing.")
                shouldCreate = true
            }
        }
        
        if shouldCreate {
            if name == defaultBookName {
                print("⚠️ Default book missing. Creating new Default book.")
                createNewBook(name: defaultBookName)
                return
            } else {
                print("⚠️ Fallback to Default.")
                loadBook(name: defaultBookName)
                return
            }
        }
        
        currentBookName = name
        UserDefaults.standard.set(name, forKey: "LastOpenBook")
        
        // 載入資料
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            self.words = CSVHelper.decode(content)
            print("📖 Loaded book: \(name) (\(words.count) words)")
        } catch {
            print("❌ Load Error for \(name): \(error). Fallback to empty list.")
            self.words = []
            
            if name == defaultBookName {
                print("⚠️ Default book corrupted. Re-creating.")
                createNewBook(name: defaultBookName)
            }
        }
    }
    
    /// 建立新單詞本
    func createNewBook(name: String) {
        guard !name.isEmpty else { return }
        let folderURL = storageDirectory.appendingPathComponent(name)
        let mediaURL = folderURL.appendingPathComponent("media")
        let fileURL = folderURL.appendingPathComponent("\(name).\(extensionName)")
        
        do {
            // 建立資料夾
            try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
            
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                let header = CSVHelper.header + "\n"
                try header.write(to: fileURL, atomically: true, encoding: .utf8)
                print("✅ Created new book structure: \(name)")
                loadBook(name: name)
                refreshAvailableBooks()
            } else {
                print("⚠️ Book csv already exists.")
                loadBook(name: name) // Reload just in case
            }
        } catch {
            print("❌ Failed to create book: \(error)")
        }
    }
    
    /// 刪除單詞本
    func deleteBook(name: String) {
        guard name != defaultBookName else { return }
        
        let folderURL = storageDirectory.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.removeItem(at: folderURL)
                print("🗑️ Deleted book folder: \(name)")
                
                if currentBookName == name {
                    loadBook(name: defaultBookName)
                }
                refreshAvailableBooks()
            }
        } catch {
            print("❌ Failed to delete book: \(error)")
        }
    }
    
    // MARK: - Global Search
    
    /// 搜尋所有單詞本
    func findWordGlobally(targetWord: String) -> WordEntry? {
        let target = targetWord.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let found = words.first(where: { $0.word.caseInsensitiveCompare(target) == .orderedSame }) {
            return found
        }
        
        for bookName in availableBooks {
            if bookName == currentBookName { continue }
            
            let folderURL = storageDirectory.appendingPathComponent(bookName)
            let fileURL = folderURL.appendingPathComponent("\(bookName).\(extensionName)")
            
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                let bookWords = CSVHelper.decode(content)
                if let found = bookWords.first(where: { $0.word.caseInsensitiveCompare(target) == .orderedSame }) {
                    return found
                }
            }
        }
        return nil
    }

    // MARK: - Path & Migration Management
    
    /// 變更儲存位置
    func changeStorageLocation(to newURL: URL) throws {
        let accessing = newURL.startAccessingSecurityScopedResource()
        let oldDirectory = storageDirectory
        
        do {
            // 搬移所有資料夾
            try moveAllContent(from: oldDirectory, to: newURL)
            
            let bookmarkData = try newURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            
            customStorageURL?.stopAccessingSecurityScopedResource()
            customStorageURL = newURL
            
            loadBook(name: currentBookName)
            refreshAvailableBooks()
            
        } catch {
            if accessing { newURL.stopAccessingSecurityScopedResource() }
            throw error
        }
    }
    
    private func moveAllContent(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        
        // 確保目標資料夾存在
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }
        
        // 為了避免移動到非 App 相關的檔案，我們只移動符合單詞本結構的資料夾。
        let files = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        for file in files {
            // 檢查是否為資料夾
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: file.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            
            let name = file.lastPathComponent
            // 檢查是否包含同名 csv (e.g., Default/Default.csv)
            let csvPath = file.appendingPathComponent("\(name).\(extensionName)")
            
            if fileManager.fileExists(atPath: csvPath.path) {
                let targetURL = destination.appendingPathComponent(name)
                
                print("🚚 Moving book found: \(name) from \(file.path) to \(targetURL.path)")
                
                // 如果目標已存在，先移除舊的以確保移動成功
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                try fileManager.moveItem(at: file, to: targetURL)
            }
        }
    }
    
    private func restoreSecurityScopedAccess() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if url.startAccessingSecurityScopedResource() {
                customStorageURL = url
                if isStale {
                    let newData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(newData, forKey: bookmarkKey)
                }
            }
        } catch {
            print("⚠️ Failed to restore storage bookmark: \(error)")
        }
    }
    
    // MARK: - Migration Logic (Flat to Folder)
    
    private func migrateFileStructure() {
        // 1. JSON to CSV (Old migration logic kept for safety)
        migrateJSONToCSV()
        
        // 2. Flat to Folder (New migration)
        do {
            let files = try FileManager.default.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            let csvFiles = files.filter { $0.pathExtension == extensionName }
            
            for csvURL in csvFiles {
                let bookName = csvURL.deletingPathExtension().lastPathComponent
                
                // 如果已經在資料夾結構中（我們是掃 root），這裡只會掃到 root 的 csv
                // 如果是 Documents/Book/Book.csv，這裡不會掃到 (因為沒遞迴)
                // 所以掃到的都是未遷移的 root CSV
                
                print("🔄 Migrating Book Structure for: \(bookName)")
                
                // 建立目標資料夾結構
                let bookFolder = storageDirectory.appendingPathComponent(bookName)
                let mediaFolder = bookFolder.appendingPathComponent("media")
                let targetCSV = bookFolder.appendingPathComponent("\(bookName).\(extensionName)")
                
                if !FileManager.default.fileExists(atPath: mediaFolder.path) {
                    try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true, attributes: nil)
                }
                
                // 讀取 CSV 內容以找出相關媒體檔案
                if let content = try? String(contentsOf: csvURL, encoding: .utf8) {
                    var words = CSVHelper.decode(content)
                    
                    // 搬移媒體檔案並更新路徑
                    for i in 0..<words.count {
                        // 處理圖片
                        if let imgPath = words[i].localImagePath, !imgPath.isEmpty {
                            if migrateMediaFile(filename: imgPath, to: mediaFolder) {
                                // 加上 media/ 前綴
                                if !imgPath.contains("/") {
                                    words[i].localImagePath = "media/\(imgPath)"
                                }
                            }
                        }
                        
                        // 處理聲音
                        if let sp = words[i].soundPath, migrateMediaFile(filename: sp, to: mediaFolder) {
                            if !sp.contains("/") { words[i].soundPath = "media/\(sp)" }
                        }
                        if let smp = words[i].soundMeaningPath, migrateMediaFile(filename: smp, to: mediaFolder) {
                            if !smp.contains("/") { words[i].soundMeaningPath = "media/\(smp)" }
                        }
                        if let sep = words[i].soundExamplePath, migrateMediaFile(filename: sep, to: mediaFolder) {
                            if !sep.contains("/") { words[i].soundExamplePath = "media/\(sep)" }
                        }
                    }
                    
                    // 寫入新的 CSV 到資料夾中
                    let newContent = CSVHelper.encode(words)
                    try newContent.write(to: targetCSV, atomically: true, encoding: .utf8)
                    
                    // 移除舊 CSV
                    try FileManager.default.removeItem(at: csvURL)
                    print("✅ Migrated \(bookName) to folder structure.")
                }
            }
        } catch {
            print("⚠️ Migration failed: \(error)")
        }
    }
    
    private func migrateMediaFile(filename: String, to folder: URL) -> Bool {
        // 舊檔案在 root (只取檔名，忽略舊路徑中的目錄如果有的話)
        let name = filename.components(separatedBy: "/").last ?? filename
        let oldURL = storageDirectory.appendingPathComponent(name)
        let targetURL = folder.appendingPathComponent(name)
        
        if FileManager.default.fileExists(atPath: oldURL.path) {
            do {
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }
                try FileManager.default.moveItem(at: oldURL, to: targetURL)
                return true
            } catch {
                print("❌ Failed to move media \(filename): \(error)")
            }
        } else {
             // 檔案不在 root? 可能已經移過了? 或者根本不存在
        }
        return false
    }

    private func migrateJSONToCSV() {
        let jsonExtension = "json"
        do {
            let files = try FileManager.default.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == jsonExtension }
            
            for url in jsonFiles {
                let name = url.deletingPathExtension().lastPathComponent
                print("🔄 Migrating \(name).json to .csv...")
                
                if let data = try? Data(contentsOf: url),
                   let oldWords = try? JSONDecoder().decode([WordEntry].self, from: data) {
                    
                    let csvString = CSVHelper.encode(oldWords)
                    // 寫入 CSV (這會觸發下次 migrateFileStructure 把它搬到資料夾)
                    let csvURL = storageDirectory.appendingPathComponent(name).appendingPathExtension("csv")
                    try csvString.write(to: csvURL, atomically: true, encoding: .utf8)
                    
                    try FileManager.default.removeItem(at: url)
                    print("✅ Migrated \(name) to CSV.")
                }
            }
        } catch {
            print("⚠️ Migration failed: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    /// 儲存全新匯入的單字（含圖片處理）
    func saveNewWord(entry: WordEntry, imageData: Data?) {
        var newEntry = entry
        
        if let data = imageData {
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "\(entry.word)_\(timestamp).png"
            let fileURL = currentMediaFolder.appendingPathComponent(fileName)
            
            do {
                if !FileManager.default.fileExists(atPath: currentMediaFolder.path) {
                    try FileManager.default.createDirectory(at: currentMediaFolder, withIntermediateDirectories: true)
                }
                try data.write(to: fileURL)
                newEntry.localImagePath = "media/\(fileName)"
            } catch {
                print("❌ Failed to save word image: \(error)")
            }
        }
        
        addWord(newEntry)
    }
    
    /// 新增或更新單字
    func addWord(_ word: WordEntry) {
        if let index = words.firstIndex(where: { $0.word.lowercased() == word.word.lowercased() }) {
            words[index] = mergeUserProgress(from: words[index], into: word)
        } else {
            words.append(word)
        }
        saveWords()
    }
    
    /// 更新單字圖片
    func updateImage(for wordID: String, imageData: Data) {
        guard let index = words.firstIndex(where: { $0.id == wordID }) else { return }
        
        // Remove old
        if let oldPath = words[index].localImagePath {
            let oldURL = resolveFileURL(for: oldPath)
            try? FileManager.default.removeItem(at: oldURL)
        }
        
        // Save new
        let newFileName = "\(words[index].word)_\(Int(Date().timeIntervalSince1970)).png"
        let newURL = currentMediaFolder.appendingPathComponent(newFileName)
        
        do {
             if !FileManager.default.fileExists(atPath: currentMediaFolder.path) {
                try FileManager.default.createDirectory(at: currentMediaFolder, withIntermediateDirectories: true)
            }
            try imageData.write(to: newURL)
            words[index].localImagePath = "media/\(newFileName)"
            saveWords()
        } catch {
            print("❌ Failed to update image: \(error)")
        }
    }
    
    /// 更新單字文字資訊
    func updateWordInfo(for wordID: String, phonetic: String, translation: String?, meaning: String, meaningTranslation: String?, example: String, exampleTranslation: String, soundPath: String? = nil, soundMeaningPath: String? = nil, soundExamplePath: String? = nil) {
        guard let index = words.firstIndex(where: { $0.id == wordID }) else { return }
        
        words[index].phonetic = phonetic
        words[index].translation = translation
        words[index].meaning = meaning
        words[index].meaningTranslation = meaningTranslation
        words[index].example = example
        words[index].exampleTranslation = exampleTranslation
        
        if let sp = soundPath { words[index].soundPath = sp }
        if let smp = soundMeaningPath { words[index].soundMeaningPath = smp }
        if let sep = soundExamplePath { words[index].soundExamplePath = sep }
        
        saveWords()
    }
    
    /// Import Library from folder
    func importLibrary(from folderURL: URL) throws {
        // Ensure media folder exists
        if !FileManager.default.fileExists(atPath: currentMediaFolder.path) {
            try FileManager.default.createDirectory(at: currentMediaFolder, withIntermediateDirectories: true)
        }
        
        // Import to media folder
        let newWords = try LibraryImporter.importLibrary(from: folderURL, to: currentMediaFolder)
        
        for var word in newWords {
            // Update paths to include "media/" prefix
            if let path = word.localImagePath, !path.isEmpty { word.localImagePath = "media/\(path)" }
            if let path = word.soundPath, !path.isEmpty { word.soundPath = "media/\(path)" }
            if let path = word.soundMeaningPath, !path.isEmpty { word.soundMeaningPath = "media/\(path)" }
            if let path = word.soundExamplePath, !path.isEmpty { word.soundExamplePath = "media/\(path)" }
            
            // Merge logic
            if let index = words.firstIndex(where: { $0.word.lowercased() == word.word.lowercased() }) {
                words[index] = mergeUserProgress(from: words[index], into: word)
            } else {
                words.append(word)
            }
        }
        
        saveWords()
        print("✅ Imported \(newWords.count) words from \(folderURL.path)")
    }
    
    /// 切換收藏狀態
    func toggleFavorite(for wordID: String) {
        if let index = words.firstIndex(where: { $0.id == wordID }) {
            words[index].isFavorite.toggle()
            saveWords()
        }
    }
    
    /// 根據答題結果更新遺忘曲線排程與錯誤統計
    func recordPracticeResult(for wordID: String, errorCount: Int, reviewedAt: Date = Date()) {
        if let index = words.firstIndex(where: { $0.id == wordID }) {
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
            saveWords()
        }
    }
    
    /// 批量刪除單字
    func deleteWords(at offsets: IndexSet) {
        for index in offsets {
            if let imgPath = words[index].localImagePath {
                let url = resolveFileURL(for: imgPath)
                try? FileManager.default.removeItem(at: url)
            }
            // Optional: Also delete sounds
        }
        words.remove(atOffsets: offsets)
        saveWords()
    }
    
    // MARK: - Persistence
    
    private func saveWords() {
        do {
            let csvString = CSVHelper.encode(words)
            try csvString.write(to: currentBookURL, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Persistence Error: \(error)")
        }
    }

    private func mergeUserProgress(from existing: WordEntry, into incoming: WordEntry) -> WordEntry {
        var merged = incoming
        merged.isFavorite = existing.isFavorite || incoming.isFavorite
        merged.mistakeCount = max(existing.mistakeCount ?? 0, incoming.mistakeCount ?? 0)
        merged.reviewStage = max(existing.reviewStage ?? 0, incoming.reviewStage ?? 0)
        merged.lastReviewedAt = incoming.lastReviewedAt ?? existing.lastReviewedAt
        merged.nextReviewAt = incoming.nextReviewAt ?? existing.nextReviewAt
        return merged
    }

    private static func retryInterval(for errorCount: Int) -> TimeInterval {
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
