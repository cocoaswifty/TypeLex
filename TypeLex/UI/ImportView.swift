import SwiftUI

struct ImportView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    private let geminiService = GeminiService()
    
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var progressMessage: String = ""
    @State private var importedCount: Int = 0
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Data stored at:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Change Location") {
                    selectNewLocation()
                }
                .font(.caption)
                .buttonStyle(LinkButtonStyle())
                .pointingCursor()
            }
            
            Text(repository.dataFilePath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.blue)
                .contextMenu {
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(repository.dataFilePath, forType: .string)
                    }
                }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Storage Folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Update UI to show processing state
                self.isProcessing = true
                self.progressMessage = "Moving data to new location..."
                self.feedback = nil
                let repository = self.repository
                
                Task(priority: .userInitiated) {
                    do {
                        try repository.changeStorageLocation(to: url)
                        
                        await MainActor.run {
                            self.feedback = InlineFeedback(
                                title: "Storage Updated",
                                message: "Successfully moved data to the new location.",
                                style: .success
                            )
                            self.isProcessing = false
                        }
                    } catch {
                        await MainActor.run {
                            self.feedback = InlineFeedback(
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
    }
    
    func startImport() {
        let words = inputText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !words.isEmpty else { return }
        
        isProcessing = true
        feedback = nil
        importedCount = 0
        let totalCount = words.count
        print("🚀 Start importing \(totalCount) words...")
        
        Task {
            var hasError = false
            for (index, word) in words.enumerated() {
                do {
                    print("➡️ [\(index + 1)/\(totalCount)] Processing: \(word)")
                    try await processWord(word, index: index + 1, total: totalCount)
                } catch {
                    print("❌ Error processing '\(word)': \(error)")
                    hasError = true
                    break
                }
            }
            
            await MainActor.run {
                isProcessing = false
                print("🏁 Import session finished. Success: \(importedCount)/\(totalCount)")
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
            print("   ↳ Found locally: \(existingEntry.id)")
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            await MainActor.run {
                self.progressMessage = "\(prefix) Found in local library!"
                self.repository.saveNewWord(entry: existingEntry, imageData: nil)
                self.importedCount += 1
            }
            return
        }
        
        await MainActor.run {
            progressMessage = "\(prefix) Generating definitions (Gemini AI)..."
        }
        print("   ↳ Generating AI content...")
        
        do {
            // 1. Generate Text (Gemini)
            let info = try await geminiService.fetchWordInfo(word: word)
            
            await MainActor.run {
                progressMessage = "\(prefix) Generating illustration (Pollinations/Stability)..."
            }
            
            // 2. Generate Image (ImageService)
            let imageData = try await ImageService.shared.generateImage(context: info.example)
            
            print("   ↳ AI Generation success. Saving...")
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
                importedCount += 1
            }
            
        } catch {
            print("   ↳ AI Generation failed: \(error)")
            await MainActor.run {
                if let geminiError = error as? GeminiError {
                    switch geminiError {
                    case .missingApiKey:
                        feedback = InlineFeedback(
                            title: "Missing API Key",
                            message: "Gemini key is not set. Open Settings to add one or rely on the existing fallback flow.",
                            style: .failure
                        )
                    case .apiError(let message):
                        feedback = InlineFeedback(
                            title: "Import Failed",
                            message: message,
                            style: .failure
                        )
                    default:
                        feedback = InlineFeedback(
                            title: "Import Failed",
                            message: "Error importing '\(word)': \(error.localizedDescription)",
                            style: .failure
                        )
                    }
                } else {
                    feedback = InlineFeedback(
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
