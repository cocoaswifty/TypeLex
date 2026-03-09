import Foundation
import OSLog

extension PracticeViewModel {
    /// Load the built-in default library (@4000 Words)
    func loadDefaultLibrary(completion: ((Bool) -> Void)? = nil) {
        libraryPicker.chooseLibrary(
            prompt: "Select Library",
            message: "Please select the folder or ZIP file containing the library data."
        ) { url in
            self.handleLibrarySelection(
                from: url,
                failureTitle: "Load Failed",
                failureMessage: "The selected library could not be loaded.",
                completion: completion
            )
        }
    }

    /// Import a custom library from a folder
    func importCustomLibrary(completion: ((Bool) -> Void)? = nil) {
        libraryPicker.chooseLibrary(prompt: "Import Library", message: nil) { url in
            self.handleLibrarySelection(
                from: url,
                failureTitle: "Import Failed",
                failureMessage: "The selected library could not be imported.",
                completion: completion
            )
        }
    }

    /// 播放發音
    /// - Parameter count: 播放次數 (預設 1 次)
    func speakCurrentWord(count: Int? = nil) {
        if isEmptyState || currentEntry.id == "abandon" { return }

        let preferences = PracticePreferences.load(using: userDefaults)
        let playbackCount = max(1, count ?? preferences.wordPlaybackCount)
        let playbackDelayNanoseconds = UInt64(max(0.3, preferences.wordPlaybackDelay) * 1_000_000_000)

        speechTask?.cancel()
        playAudioForCurrentWord()

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

    /// 播放意義發音
    func speakMeaning() {
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
        refreshCurrentEntry()
    }

    /// 重新生成圖片
    func regenerateCurrentImage() {
        guard !isRegeneratingImage else { return }
        isRegeneratingImage = true

        let targetEntry = currentEntry

        Task {
            do {
                if let imageData = try await contentGenerator.regenerateImage(for: targetEntry) {
                    repository.updateImage(for: targetEntry.id, imageData: imageData)
                    refreshCurrentEntry(ifMatching: targetEntry.id)
                } else {
                    presentAlert("AI 繪圖伺服器沒有回應，請稍後再試。")
                }
            } catch {
                presentAlert("連線逾時或網路錯誤，請檢查您的網路連線。")
            }
            isRegeneratingImage = false
        }
    }

    /// 重新生成文字資訊
    func regenerateCurrentText() {
        guard !isRegeneratingText else { return }
        isRegeneratingText = true

        let targetEntry = currentEntry

        Task {
            do {
                let info = try await contentGenerator.regenerateWordInfo(word: targetEntry.word)

                repository.updateWordInfo(
                    for: targetEntry.id,
                    phonetic: info.phonetic,
                    translation: info.translation,
                    meaning: info.meaning,
                    meaningTranslation: info.meaningTranslation,
                    example: info.example,
                    exampleTranslation: info.exampleTranslation
                )

                refreshCurrentEntry(ifMatching: targetEntry.id)
            } catch {
                presentAlert("文字資料更新失敗，請稍後再試。")
            }
            isRegeneratingText = false
        }
    }

    func handleLibrarySelection(
        from url: URL?,
        failureTitle: String,
        failureMessage: String,
        completion: ((Bool) -> Void)?
    ) {
        guard let url else {
            completion?(false)
            return
        }

        do {
            try repository.importLibrary(from: url)
            refreshQueue()
            completion?(true)
        } catch {
            AppCrashReporter.shared.record(error, context: "library_import")
            AppLogger.app.error("Library import failed: \(error.localizedDescription)")
            presentLibraryImportFailure(
                title: failureTitle,
                message: failureMessage,
                error: error
            )
            completion?(false)
        }
    }

    func playAudioForCurrentWord() {
        if let soundPath = currentEntry.soundPath {
            let url = repository.resolveFileURL(for: soundPath)
            if FileManager.default.fileExists(atPath: url.path) {
                speechService.playAudio(at: url)
                return
            }
        }
        speechService.speak(currentEntry.word)
    }

    func playExampleForCurrentWord() {
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

    func showEntry(_ entry: WordEntry, shouldSpeak: Bool = true) {
        currentEntry = entry
        engine.reset(newWord: entry.word)

        if shouldSpeak {
            speakCurrentWord()
        }
    }

    func refreshCurrentEntry() {
        refreshCurrentEntry(ifMatching: currentEntry.id)
    }

    func refreshCurrentEntry(ifMatching wordID: String) {
        guard currentEntry.id == wordID else { return }
        guard let updatedWord = repository.words.first(where: { $0.id == wordID }) else { return }
        currentEntry = updatedWord
    }
}
