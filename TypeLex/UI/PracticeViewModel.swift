import AppKit
import Observation

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
    var screenState: PracticeScreenState = .emptyLibrary
    
    private var isTransitioning: Bool = false
    
    // MARK: - Dependencies
    
    let repository = WordRepository() // Public for ImportView access
    let geminiService = GeminiService() // Need access for regeneration
    let speechService = SpeechService.shared
    let userDefaults: UserDefaults
    
    private var history: [WordEntry] = []
    var speechTask: Task<Void, Never>?

    var isEmptyState: Bool {
        repository.words.isEmpty
    }
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let preferences = PracticePreferences.load(using: userDefaults)
        self.practiceMode = PracticeMode(rawValue: preferences.defaultPracticeMode) ?? .all

        // Initialize with first word from repository
        if repository.words.isEmpty {
            self.screenState = .emptyLibrary
            let startWord = WordEntry.mock
            self.currentEntry = startWord
            self.engine = TypingEngine(targetWord: startWord.word)
            // Do NOT speak in empty state
        } else {
            self.screenState = .ready
            let startWord = PracticeWordSelector.selectNextWord(from: repository.words) ?? repository.words.first!
            self.currentEntry = startWord
            self.engine = TypingEngine(targetWord: startWord.word)
            
            // Speak only if we have real words
            speakCurrentWord()
        }
    }
    
    /// Reloads the queue from repository (called after import)
    func refreshQueue() {
        self.screenState = repository.words.isEmpty ? .emptyLibrary : .ready
        
        if !repository.words.isEmpty {
            if currentEntry.id == WordEntry.mock.id || currentEntry.id == "abandon" {
                 if let next = PracticeWordSelector.selectNextWord(from: repository.words) ?? repository.words.first {
                     showEntry(next)
                 }
            } else if let lastAdded = repository.words.last, lastAdded.id != currentEntry.id {
                if engine.cursorIndex == 0 {
                    showEntry(lastAdded)
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
        if !PracticeWordSelector.isWordValid(currentEntry, for: practiceMode) {
            nextWord()
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
    
    // MARK: - Navigation
    
    func skipWord() {
        nextWord()
    }
    
    func goToPreviousWord() {
        guard let previous = history.popLast() else { return }
        showEntry(previous)
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
        let pool = PracticeWordSelector.words(for: practiceMode, from: allWords)
        
        guard !pool.isEmpty else {
            if practiceMode != .all {
                self.practiceMode = .all
                self.nextWord()
            }
            return
        }

        let next = PracticeWordSelector.nextWord(
            from: pool,
            recentHistory: history,
            currentEntry: currentEntry,
            recentWordLimit: Self.recentWordLimit
        ) ?? currentEntry
        
        showEntry(next)
    }

    func presentScreenFailure(title: String, message: String) {
        screenState = .failure(title: title, message: message)
    }

    func presentLibraryImportFailure(title: String, message: String, error: Error) {
        if repository.words.isEmpty {
            presentScreenFailure(title: title, message: message)
            return
        }

        presentAlert("\(title): \(error.localizedDescription)")
    }

    func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
