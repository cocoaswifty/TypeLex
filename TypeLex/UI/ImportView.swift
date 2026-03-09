import SwiftUI

struct ImportView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    private let geminiService = GeminiService()
    
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
            Text("Import Words")
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
            .pointingCursor()
            
            Button("Import & Generate") {
                startImport()
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .pointingCursor()
        }
    }
}

// MARK: - Handlers

private extension ImportView {
    func selectNewLocation() {
        StorageLocationPicker.present { url in
            guard let url else { return }

            self.isProcessing = true
            self.progressMessage = "Moving data to new location..."
            self.feedback = nil
            let repository = self.repository

            Task(priority: .userInitiated) {
                do {
                    try repository.changeStorageLocation(to: url)

                    await MainActor.run {
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
            let info = try await geminiService.fetchWordInfo(word: word)
            
            await MainActor.run {
                progressMessage = "\(prefix) Generating illustration (Pollinations/Stability)..."
            }
            
            // 2. Generate Image (ImageService)
            let imageData = try await ImageService.shared.generateImage(context: info.example)
            
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
