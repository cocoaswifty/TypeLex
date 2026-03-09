import Foundation
import Observation
import OSLog

/// 管理單字資料的儲存、持久化與路徑管理
@Observable
class WordRepository {
    var words: [WordEntry] = []
    var reviewEvents: [ReviewEvent] = []
    var currentBookName: String = "Default"
    var availableBooks: [String] = []
    
    private let extensionName = "csv"
    private let defaultBookName = "Default"
    let fileManager: FileManager
    private let userDefaults: UserDefaults
    private var storageDirectoryOverride: URL?
    static let forgettingCurveIntervals: [TimeInterval] = [
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

    var storageSupport: WordRepositoryStorage {
        WordRepositoryStorage(
            fileManager: fileManager,
            storageDirectory: storageDirectory,
            extensionName: extensionName
        )
    }

    private var migrationSupport: WordRepositoryMigration {
        WordRepositoryMigration(
            fileManager: fileManager,
            storageDirectory: storageDirectory,
            extensionName: extensionName
        )
    }
    
    /// 目前的儲存根目錄 (預設為 ~/Downloads/TypeLexLibrary)
    var storageDirectory: URL {
        if let storageDirectoryOverride { return storageDirectoryOverride }
        if let custom = customStorageURL { return custom }
        
        let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        return downloads.appendingPathComponent("TypeLexLibrary")
    }
    
    /// 目前單詞本的資料夾路徑 (例如 Documents/Default/)
    var currentBookFolder: URL {
        storageSupport.bookFolderURL(named: currentBookName)
    }
    
    /// 目前單詞本的 CSV 路徑 (例如 Documents/Default/Default.csv)
    var currentBookURL: URL {
        storageSupport.bookCSVURL(named: currentBookName)
    }
    
    /// 目前單詞本的媒體資料夾路徑 (例如 Documents/Default/media/)
    var currentMediaFolder: URL {
        storageSupport.bookMediaFolderURL(named: currentBookName)
    }
    
    /// 為了相容性保留的屬性，等同於 currentBookURL.path
    var dataFilePath: String {
        currentBookURL.path
    }
    
    // MARK: - Initialization
    
    init(
        storageDirectoryOverride: URL? = nil,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        performStartupTasks: Bool = true
    ) {
        self.storageDirectoryOverride = storageDirectoryOverride
        self.userDefaults = userDefaults
        self.fileManager = fileManager

        if let storageDirectoryOverride, !fileManager.fileExists(atPath: storageDirectoryOverride.path) {
            try? fileManager.createDirectory(at: storageDirectoryOverride, withIntermediateDirectories: true)
        }

        if performStartupTasks && storageDirectoryOverride == nil {
            restoreSecurityScopedAccess()
        }

        if performStartupTasks {
            migrateFileStructure()
        }
        
        // 載入上次使用的單詞本，或是預設本
        let lastBook = userDefaults.string(forKey: "LastOpenBook") ?? defaultBookName
        loadBook(name: lastBook)
        
        refreshAvailableBooks()
    }

    // MARK: - Path Helpers
    
    /// 取得檔案的完整路徑（相對於當前單詞本）
    /// - Parameter path: 相對路徑 (e.g., "media/image.png")
    /// - Returns: 完整 URL
    func resolveFileURL(for path: String) -> URL {
        storageSupport.fileURL(for: path, inBookNamed: currentBookName)
    }

    // MARK: - Book Management
    
    /// 刷新可用單詞本列表 (掃描資料夾)
    func refreshAvailableBooks() {
        do {
            self.availableBooks = try storageSupport.refreshAvailableBooks()
        } catch {
            AppLogger.repository.error("Failed to list books: \(error.localizedDescription)")
            self.availableBooks = []
        }
    }
    
    /// 切換單詞本
    func loadBook(name: String) {
        let fileURL = storageSupport.bookCSVURL(named: name)
        
        var shouldCreate = false
        
        // 檢查資料夾與檔案是否存在
        if !fileManager.fileExists(atPath: fileURL.path) {
            AppLogger.repository.warning("Book \(name, privacy: .public) not found at \(fileURL.path, privacy: .public)")
            shouldCreate = true
        } else {
            // 檢查檔案大小
            if let attr = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attr[.size] as? UInt64, size == 0 {
                AppLogger.repository.warning("Book \(name, privacy: .public) is empty and will be treated as missing")
                shouldCreate = true
            }
        }
        
        if shouldCreate {
            if name == defaultBookName {
                AppLogger.repository.warning("Default book missing. Recreating default book")
                createNewBook(name: defaultBookName)
                return
            } else {
                AppLogger.repository.warning("Falling back to default book")
                loadBook(name: defaultBookName)
                return
            }
        }
        
        currentBookName = name
        userDefaults.set(name, forKey: "LastOpenBook")
        
        // 載入資料
        do {
            self.words = try storageSupport.loadWords(fromBookNamed: name)
            self.reviewEvents = storageSupport.loadReviewEvents(fromBookNamed: name)
        } catch {
            AppLogger.repository.error("Failed to load book \(name, privacy: .public): \(error.localizedDescription)")
            self.words = []
            self.reviewEvents = []
            
            if name == defaultBookName {
                AppLogger.repository.warning("Default book appears corrupted and will be recreated")
                createNewBook(name: defaultBookName)
            }
        }
    }
    
    /// 建立新單詞本
    func createNewBook(name: String) {
        guard !name.isEmpty else { return }
        
        do {
            let created = try ensureBookExists(named: name)
            if !created {
                AppLogger.repository.warning("Book CSV already exists for \(name, privacy: .public)")
            }
            loadBook(name: name)
            refreshAvailableBooks()
        } catch {
            AppLogger.repository.error("Failed to create book \(name, privacy: .public): \(error.localizedDescription)")
        }
    }
    
    /// 刪除單詞本
    func deleteBook(name: String) {
        guard name != defaultBookName else { return }
        
        let folderURL = storageSupport.bookFolderURL(named: name)
        do {
            if fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.removeItem(at: folderURL)
                
                if currentBookName == name {
                    loadBook(name: defaultBookName)
                }
                refreshAvailableBooks()
            }
        } catch {
            AppLogger.repository.error("Failed to delete book \(name, privacy: .public): \(error.localizedDescription)")
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

            if let bookWords = try? storageSupport.loadWords(fromBookNamed: bookName),
               let found = bookWords.first(where: { $0.word.caseInsensitiveCompare(target) == .orderedSame }) {
                return found
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
            try storageSupport.moveAllContent(from: oldDirectory, to: newURL)
            
            let bookmarkData = try newURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            userDefaults.set(bookmarkData, forKey: bookmarkKey)
            
            customStorageURL?.stopAccessingSecurityScopedResource()
            customStorageURL = newURL
            if storageDirectoryOverride != nil {
                storageDirectoryOverride = newURL
            }
            
            loadBook(name: currentBookName)
            refreshAvailableBooks()
            
        } catch {
            if accessing { newURL.stopAccessingSecurityScopedResource() }
            throw error
        }
    }
    
    private func restoreSecurityScopedAccess() {
        guard let data = userDefaults.data(forKey: bookmarkKey) else { return }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if url.startAccessingSecurityScopedResource() {
                customStorageURL = url
                if isStale {
                    let newData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    userDefaults.set(newData, forKey: bookmarkKey)
                }
            }
        } catch {
            AppLogger.storage.warning("Failed to restore storage bookmark: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Migration Logic (Flat to Folder)
    
    private func migrateFileStructure() {
        migrationSupport.migrateFileStructure()
    }
    
    func reviewStatsSummary(now: Date = Date(), calendar: Calendar = .current) -> ReviewStatsSummary {
        WordRepositoryStatsCalculator(words: words, reviewEvents: reviewEvents)
            .reviewStatsSummary(now: now, calendar: calendar)
    }

    func recentDailyProgress(days: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> [ReviewDailyProgress] {
        WordRepositoryStatsCalculator(words: words, reviewEvents: reviewEvents)
            .recentDailyProgress(days: days, now: now, calendar: calendar)
    }

    func reviewCalendarMonth(referenceDate: Date = Date(), calendar: Calendar = .current) -> [ReviewCalendarDay] {
        WordRepositoryStatsCalculator(words: words, reviewEvents: reviewEvents)
            .reviewCalendarMonth(referenceDate: referenceDate, calendar: calendar)
    }
    
    // MARK: - Persistence
    
    func saveWords() {
        do {
            try storageSupport.saveWords(words, toBookNamed: currentBookName)
        } catch {
            AppLogger.repository.error("Word persistence failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func ensureBookExists(named bookName: String) throws -> Bool {
        try storageSupport.ensureBookExists(named: bookName)
    }

    func saveReviewEvents() {
        do {
            try storageSupport.saveReviewEvents(reviewEvents, toBookNamed: currentBookName)
        } catch {
            AppLogger.repository.error("Review event persistence failed: \(error.localizedDescription)")
        }
    }
}
