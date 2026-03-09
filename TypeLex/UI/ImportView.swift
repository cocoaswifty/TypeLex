import SwiftUI
import OSLog

struct ImportView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    let contentGenerator: WordContentGenerating = GeminiService()
    let imageGenerator: ImageGenerating = ImageService.shared
    let storageLocationPicker: StorageLocationPicking = AppPanelService()
    let telemetry: TelemetryTracking = AppTelemetry.shared
    
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var progressMessage: String = ""
    @State private var feedback: InlineFeedback?
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection

            if let feedback {
                InlineFeedbackView(feedback: feedback) {
                    self.feedback = nil
                }
            }
            
            inputSection
            
            storageSection
            
            if isProcessing {
                processingOverlay
            }
            
            actionsSection
        }
        .padding(30)
        .frame(width: 500, height: 450)
    }
}

// MARK: - Subviews

private extension ImportView {
    var headerSection: some View {
        VStack(spacing: 8) {
            Text(AppStrings.importWordsTitle)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Enter English words (one per line). AI will generate definitions and images.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    var inputSection: some View {
        TextEditor(text: $inputText)
            .font(.body)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .frame(minHeight: 150)
            .accessibilityLabel("Words to import")
            .accessibilityHint("Enter one English word per line")
            .disabled(isProcessing)
    }

    var storageSection: some View {
        StorageLocationSummaryView(
            path: repository.dataFilePath,
            changeTitle: "Change Location",
            buttonKind: .link,
            onChange: selectNewLocation
        )
        .padding(.horizontal, 4)
    }
    
    var processingOverlay: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Processing...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(progressMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .id(progressMessage)
                    .transition(.push(from: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    var actionsSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .disabled(isProcessing)
            .accessibilityLabel("Cancel import")
            .pointingCursor()
            
            Button("Import & Generate") {
                startImport()
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .accessibilityLabel("Import and generate content")
            .pointingCursor()
        }
    }
}

// MARK: - Handlers

private extension ImportView {
    func selectNewLocation() {
        storageLocationPicker.chooseStorageLocation(prompt: "Select Storage Folder") { url in
            guard let url else { return }

            self.isProcessing = true
            self.progressMessage = "Moving data to new location..."
            self.feedback = nil
            let repository = self.repository

            Task(priority: .userInitiated) {
                do {
                    try repository.changeStorageLocation(to: url)

                    await MainActor.run {
                        telemetry.track(.storageLocationChanged)
                        presentInlineFeedback(
                            $feedback,
                            title: "Storage Updated",
                            message: "Successfully moved data to the new location.",
                            style: .success
                        )
                        self.isProcessing = false
                    }
                } catch {
                    await MainActor.run {
                        AppCrashReporter.shared.record(error, context: "import_view_storage_move")
                        AppLogger.settings.error("Storage move from import view failed: \(error.localizedDescription)")
                        presentInlineFeedback(
                            $feedback,
                            title: "Storage Move Failed",
                            message: error.localizedDescription,
                            style: .failure
                        )
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    func startImport() {
        let words = inputText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !words.isEmpty else { return }
        
        isProcessing = true
        feedback = nil
        let totalCount = words.count
        telemetry.track(.libraryImportStarted(totalWords: totalCount))
        
        Task {
            var hasError = false
            for (index, word) in words.enumerated() {
                do {
                    try await processWord(word, index: index + 1, total: totalCount)
                } catch {
                    hasError = true
                    break
                }
            }
            
            await MainActor.run {
                isProcessing = false
                if !hasError {
                    telemetry.track(.libraryImportCompleted(totalWords: totalCount))
                    dismiss()
                }
            }
        }
    }
    
    func processWord(_ word: String, index: Int, total: Int) async throws {
        let prefix = "[\(index)/\(total)] \(word):"
        
        await MainActor.run {
            progressMessage = "\(prefix) Checking local library..."
        }
        
        if let existingEntry = repository.findWordGlobally(targetWord: word) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            await MainActor.run {
                self.progressMessage = "\(prefix) Found in local library!"
                self.repository.saveNewWord(entry: existingEntry, imageData: nil)
            }
            return
        }
        
        await MainActor.run {
            progressMessage = "\(prefix) Generating definitions (Gemini AI)..."
        }
        
        do {
            // 1. Generate Text (Gemini)
            let info = try await contentGenerator.fetchWordInfo(word: word)
            
            await MainActor.run {
                progressMessage = "\(prefix) Generating illustration (Pollinations/Stability)..."
            }
            
            // 2. Generate Image (ImageService)
            let imageData = try await imageGenerator.generateImage(context: info.example)
            
            await MainActor.run {
                progressMessage = "\(prefix) Saving..."
            }

            // 3. Assemble & Save
            let entry = WordEntry(
                word: word,
                phonetic: info.phonetic,
                translation: info.translation,
                meaning: info.meaning,
                meaningTranslation: info.meaningTranslation,
                example: info.example,
                exampleTranslation: info.exampleTranslation,
                imageName: nil,
                localImagePath: nil,
                isFavorite: false,
                mistakeCount: 0
            )
            
            await MainActor.run {
                repository.saveNewWord(entry: entry, imageData: imageData)
            }
            
        } catch {
            await MainActor.run {
                AppCrashReporter.shared.record(error, context: "manual_word_import")
                AppLogger.app.error("Word import failed for \(word, privacy: .public): \(error.localizedDescription)")
                telemetry.track(.libraryImportFailed(word: word, reason: error.localizedDescription))
                if let geminiError = error as? GeminiError {
                    switch geminiError {
                    case .missingApiKey:
                        presentInlineFeedback(
                            $feedback,
                            title: "Missing API Key",
                            message: "Gemini key is not set. Open Settings to add one or rely on the existing fallback flow.",
                            style: .failure
                        )
                    case .apiError(let message):
                        presentInlineFeedback(
                            $feedback,
                            title: "Import Failed",
                            message: message,
                            style: .failure
                        )
                    default:
                        presentInlineFeedback(
                            $feedback,
                            title: "Import Failed",
                            message: "Error importing '\(word)': \(error.localizedDescription)",
                            style: .failure
                        )
                    }
                } else {
                    presentInlineFeedback(
                        $feedback,
                        title: "Import Failed",
                        message: "Error importing '\(word)': \(error.localizedDescription)",
                        style: .failure
                    )
                }
            }
            throw error
        }
    }
}
