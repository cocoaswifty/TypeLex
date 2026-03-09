import SwiftUI
import Combine
import AppKit
import Observation
import UniformTypeIdentifiers

enum PracticeMode: String, CaseIterable {
    case all = "All Words"
    case favorites = "Favorites Only"
    case mistakes = "Mistakes Only"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .favorites: return "star.fill"
        case .mistakes: return "exclamationmark.triangle.fill"
        }
    }
}

enum PracticeScreenState: Equatable {
    case ready
    case emptyLibrary
    case failure(title: String, message: String)
}

@Observable
@MainActor
class PracticeViewModel {
    private static let recentWordLimit = 3

    // MARK: - Properties
    
    var currentEntry: WordEntry
    var engine: TypingEngine
    var practiceMode: PracticeMode = .all
    var isRegeneratingImage: Bool = false
    var isRegeneratingText: Bool = false
    var alertMessage: String?
    var showAlert: Bool = false
    var isEmptyState: Bool = false
    var screenState: PracticeScreenState = .emptyLibrary
    
    private var isTransitioning: Bool = false
    
    // MARK: - Dependencies
    
    let repository = WordRepository() // Public for ImportView access
    private let geminiService = GeminiService() // Need access for regeneration
    private let speechService = SpeechService.shared
    private let userDefaults: UserDefaults
    
    private var history: [WordEntry] = []
    private var speechTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let preferences = PracticePreferences.load(using: userDefaults)
        self.practiceMode = PracticeMode(rawValue: preferences.defaultPracticeMode) ?? .all

        // Initialize with first word from repository
        if repository.words.isEmpty {
            self.isEmptyState = true
            self.screenState = .emptyLibrary
            let startWord = WordEntry.mock
            self.currentEntry = startWord
            self.engine = TypingEngine(targetWord: startWord.word)
            // Do NOT speak in empty state
        } else {
            self.isEmptyState = false
            self.screenState = .ready
            let startWord = Self.selectNextWord(from: repository.words) ?? repository.words.first!
            self.currentEntry = startWord
            self.engine = TypingEngine(targetWord: startWord.word)
            
            // Speak only if we have real words
            speakCurrentWord()
        }
    }
    
    /// Load the built-in default library (@4000 Words)
    func loadDefaultLibrary(completion: ((Bool) -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, .zip]
        panel.prompt = "Select Library"
        panel.message = "Please select the folder or ZIP file containing the library data."
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try self.repository.importLibrary(from: url)
                    self.refreshQueue()
                    completion?(true)
                } catch {
                    print("❌ Failed to load default library: \(error)")
                    self.presentLibraryImportFailure(
                        title: "Load Failed",
                        message: "The selected library could not be loaded.",
                        error: error
                    )
                    completion?(false)
                }
            } else {
                completion?(false)
            }
        }
    }
    
    /// Import a custom library from a folder
    func importCustomLibrary(completion: ((Bool) -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, .zip]
        panel.prompt = "Import Library"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try self.repository.importLibrary(from: url)
                    self.refreshQueue()
                    completion?(true)
                } catch {
                    self.presentLibraryImportFailure(
                        title: "Import Failed",
                        message: "The selected library could not be imported.",
                        error: error
                    )
                    completion?(false)
                }
            } else {
                completion?(false)
            }
        }
    }
    
    /// Reloads the queue from repository (called after import)
    func refreshQueue() {
        // Update Empty State
        self.isEmptyState = repository.words.isEmpty
        self.screenState = repository.words.isEmpty ? .emptyLibrary : .ready
        
        if !repository.words.isEmpty {
            if currentEntry.id == WordEntry.mock.id || currentEntry.id == "abandon" {
                 if let next = Self.selectNextWord(from: repository.words) ?? repository.words.first {
                     self.currentEntry = next
                     self.engine.reset(newWord: next.word)
                     self.speakCurrentWord()
                 }
            } else if let lastAdded = repository.words.last, lastAdded.id != currentEntry.id {
                if engine.cursorIndex == 0 {
                    self.currentEntry = lastAdded
                    self.engine.reset(newWord: lastAdded.word)
                    self.speakCurrentWord()
                }
            }
        }
    }

    func clearScreenFailure() {
        screenState = repository.words.isEmpty ? .emptyLibrary : .ready
    }
    
    func cyclePracticeMode() {
        switch practiceMode {
        case .all: practiceMode = .favorites
        case .favorites: practiceMode = .mistakes
        case .mistakes: practiceMode = .all
        }
        
        // 檢查切換後的當前單字是否符合新模式，若不符合則切下一字
        if !isWordValidForMode(currentEntry, mode: practiceMode) {
            nextWord()
        }
    }
    
    private func isWordValidForMode(_ word: WordEntry, mode: PracticeMode) -> Bool {
        switch mode {
        case .all: return true
        case .favorites: return word.isFavorite
        case .mistakes: return (word.mistakeCount ?? 0) > 0
        }
    }

    // MARK: - User Intentions
    
    /// 處理鍵盤輸入
    func handleInput(_ char: Character) {
        _ = engine.input(char: char)
        
        // 檢查是否完成
        if engine.isFinished {
            finishCurrentWord()
        }
    }
    
    /// 播放發音
    /// - Parameter count: 播放次數 (預設 1 次)
    func speakCurrentWord(count: Int? = nil) {
        print("🔊 speakCurrentWord (ID: \(ObjectIdentifier(self))) - Word: \(currentEntry.word)")
        // Guard against speaking the mock word in empty state
        if isEmptyState || currentEntry.id == "abandon" { return }

        let preferences = PracticePreferences.load(using: userDefaults)
        let playbackCount = max(1, count ?? preferences.wordPlaybackCount)
        let playbackDelayNanoseconds = UInt64(max(0.3, preferences.wordPlaybackDelay) * 1_000_000_000)
        
        // Cancel previous task (stops pending 2nd playback)
        speechTask?.cancel()
        
        // 1. Play Immediately (First time)
        playAudioForCurrentWord()
        
        // 2. Schedule subsequent plays if needed
        if playbackCount > 1 || preferences.autoPlayExampleAudio {
            speechTask = Task { @MainActor in
                for _ in 1..<playbackCount {
                    try? await Task.sleep(nanoseconds: playbackDelayNanoseconds)
                    if Task.isCancelled { return }
                    playAudioForCurrentWord()
                }

                if preferences.autoPlayExampleAudio, currentEntry.example != nil {
                    try? await Task.sleep(nanoseconds: playbackDelayNanoseconds)
                    if Task.isCancelled { return }
                    playExampleForCurrentWord()
                }
            }
        }
    }
    
    private func playAudioForCurrentWord() {
        if let soundPath = currentEntry.soundPath {
            let url = repository.resolveFileURL(for: soundPath)
            if FileManager.default.fileExists(atPath: url.path) {
                speechService.playAudio(at: url)
                return
            }
        }
        speechService.speak(currentEntry.word)
    }
    
    /// 播放意義發音
    func speakMeaning() {
        // Cancel speech task so meaning plays immediately without interference
        speechTask?.cancel()
        
        if isEmptyState { return }
        
        if let soundPath = currentEntry.soundMeaningPath {
            let url = repository.resolveFileURL(for: soundPath)
            if FileManager.default.fileExists(atPath: url.path) {
                speechService.playAudio(at: url)
                return
            }
        }
        speechService.speak(currentEntry.meaning)
    }
    
    /// 播放例句發音
    func speakExample() {
        speechTask?.cancel()
        playExampleForCurrentWord()
    }
    
    /// 切換收藏
    func toggleFavorite() {
        repository.toggleFavorite(for: currentEntry.id)
        if let updatedWord = repository.words.first(where: { $0.id == currentEntry.id }) {
            currentEntry = updatedWord
        }
    }
    
    /// 重新生成圖片
    func regenerateCurrentImage() {
        guard !isRegeneratingImage else { return }
        isRegeneratingImage = true
        
        let targetEntry = currentEntry
        
        Task {
            do {
                if let imageData = try await geminiService.regenerateImage(for: targetEntry) {
                    // 更新 Repository
                    self.repository.updateImage(for: targetEntry.id, imageData: imageData)
                    
                    // 若當前顯示的單字沒變，則更新 UI 顯示
                    if self.currentEntry.id == targetEntry.id {
                        if let updatedWord = self.repository.words.first(where: { $0.id == targetEntry.id }) {
                            self.currentEntry = updatedWord
                        }
                    }
                } else {
                    self.presentAlert("AI 繪圖伺服器沒有回應，請稍後再試。")
                }
            } catch {
                self.presentAlert("連線逾時或網路錯誤，請檢查您的網路連線。")
            }
            self.isRegeneratingImage = false
        }
    }
    
    /// 重新生成文字資訊
    func regenerateCurrentText() {
        guard !isRegeneratingText else { return }
        isRegeneratingText = true
        
        let targetEntry = currentEntry
        
        Task {
            do {
                let info = try await geminiService.regenerateWordInfo(word: targetEntry.word)
                
                self.repository.updateWordInfo(
                    for: targetEntry.id,
                    phonetic: info.phonetic,
                    translation: info.translation,
                    meaning: info.meaning,
                    meaningTranslation: info.meaningTranslation,
                    example: info.example,
                    exampleTranslation: info.exampleTranslation
                )
                
                // 若當前顯示的單字沒變，則更新 UI 顯示
                if self.currentEntry.id == targetEntry.id {
                    if let updatedWord = self.repository.words.first(where: { $0.id == targetEntry.id }) {
                        self.currentEntry = updatedWord
                    }
                }
            } catch {
                print("Text regeneration failed: \(error)")
            }
            self.isRegeneratingText = false
        }
    }
    
    // MARK: - Navigation
    
    func skipWord() {
        nextWord()
    }
    
    func goToPreviousWord() {
        guard let previous = history.popLast() else { return }
        
        self.currentEntry = previous
        self.engine.reset(newWord: previous.word)
        speakCurrentWord()
    }
    
    // MARK: - Private Logic
    
    private func finishCurrentWord() {
        repository.recordPracticeResult(for: currentEntry.id, errorCount: engine.errorCount)
        
        guard !isTransitioning else { return }
        isTransitioning = true
        
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            self.nextWord()
        }
    }
    
    private func nextWord() {
        // Reset transitioning flag as we are now setting up the new state
        defer { isTransitioning = false }
        
        if currentEntry.id != WordEntry.mock.id {
            history.append(currentEntry)
        }
        
        let allWords = repository.words.isEmpty ? [WordEntry.mock] : repository.words
        
        let pool: [WordEntry]
        switch practiceMode {
        case .all:
            pool = allWords
        case .favorites:
            pool = allWords.filter { $0.isFavorite }
        case .mistakes:
            pool = allWords.filter { ($0.mistakeCount ?? 0) > 0 }
        }
        
        guard !pool.isEmpty else {
            if practiceMode != .all {
                self.practiceMode = .all
                self.nextWord()
            }
            return
        }

        let recentIDs = Set(history.suffix(Self.recentWordLimit).map(\.id)).union([currentEntry.id])
        let next = Self.selectNextWord(from: pool, excludingIDs: recentIDs)
            ?? Self.selectNextWord(from: pool)
            ?? currentEntry
        
        self.currentEntry = next
        self.engine.reset(newWord: next.word)
        speakCurrentWord()
    }

    private static func selectNextWord(
        from pool: [WordEntry],
        excludingIDs: Set<String> = [],
        now: Date = Date()
    ) -> WordEntry? {
        guard !pool.isEmpty else { return nil }

        let filteredPool = pool.filter { !excludingIDs.contains($0.id) }
        let candidates = filteredPool.isEmpty ? pool : filteredPool

        let reviewedDueWords = candidates
            .filter { isDue($0, now: now) && $0.nextReviewAt != nil }
            .sorted { ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture) }

        if let overdue = reviewedDueWords.first {
            return overdue
        }

        let newWords = candidates.filter { $0.nextReviewAt == nil }
        if let unseen = newWords.randomElement() {
            return unseen
        }

        let upcomingWords = candidates
            .filter { $0.nextReviewAt != nil }
            .sorted { ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture) }

        return upcomingWords.first ?? candidates.randomElement()
    }

    private static func isDue(_ word: WordEntry, now: Date) -> Bool {
        guard let nextReviewAt = word.nextReviewAt else { return true }
        return nextReviewAt <= now
    }

    private func presentScreenFailure(title: String, message: String) {
        screenState = .failure(title: title, message: message)
    }

    private func presentLibraryImportFailure(title: String, message: String, error: Error) {
        if repository.words.isEmpty {
            presentScreenFailure(title: title, message: message)
            return
        }

        presentAlert("\(title): \(error.localizedDescription)")
    }

    private func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    private func playExampleForCurrentWord() {
        if let soundPath = currentEntry.soundExamplePath {
            let url = repository.resolveFileURL(for: soundPath)
            if FileManager.default.fileExists(atPath: url.path) {
                speechService.playAudio(at: url)
                return
            }
        }
        if let example = currentEntry.example {
            speechService.speak(example)
        }
    }
}
