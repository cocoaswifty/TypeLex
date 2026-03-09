import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    
    @State private var geminiKey: String = ""
    @State private var stabilityKey: String = ""
    @State private var feedback: InlineFeedback?
    @State private var isChangingStorageLocation: Bool = false
    
    // UI Scale setting (persisted)
    @AppStorage("userUIScale") private var userUIScale: Double = 1.0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(PreferenceKeys.wordPlaybackCount) private var wordPlaybackCount = 2
    @AppStorage(PreferenceKeys.wordPlaybackDelay) private var wordPlaybackDelay = 1.3
    @AppStorage(PreferenceKeys.autoPlayExampleAudio) private var autoPlayExampleAudio = false
    @AppStorage(PreferenceKeys.showTranslations) private var showTranslations = true
    @AppStorage(PreferenceKeys.showExampleTranslation) private var showExampleTranslation = true
    @AppStorage(PreferenceKeys.defaultPracticeMode) private var defaultPracticeMode = PracticeMode.all.rawValue
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)

                if let feedback {
                    InlineFeedbackView(feedback: feedback) {
                        self.feedback = nil
                    }
                }
                
                uiScaleSection
                onboardingSection
                storageSection
                practiceSection
                geminiSection
                stabilitySection
                
                actionsSection
            }
            .padding(30)
        }
        .frame(width: 450)
        .onAppear {
            loadKeys()
        }
    }
}

// MARK: - Subviews

private extension SettingsView {
    var uiScaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .font(.headline)
            
            Text("Adjust overall UI text size. Useful for different screen sizes.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Smaller")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $userUIScale, in: 0.7...1.3, step: 0.05)
                        .frame(maxWidth: .infinity)
                    
                    Text("Larger")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Current: \(Int(userUIScale * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Button("Reset") {
                        withAnimation { userUIScale = 1.0 }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .font(.caption)
                    .disabled(abs(userUIScale - 1.0) < 0.01)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Onboarding")
                .font(.headline)

            Text("Show the first-run setup again if you want to re-run the initial library and settings flow.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Show Onboarding Again") {
                    hasCompletedOnboarding = false
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()

                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.headline)

            Text("Choose where books, CSV files, images, and audio are stored.")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(repository.storageDirectory.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.blue)
                .textSelection(.enabled)

            HStack {
                Button(isChangingStorageLocation ? "Moving..." : "Change Location") {
                    selectNewLocation()
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()
                .disabled(isChangingStorageLocation)

                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    var practiceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Default Mode", selection: $defaultPracticeMode) {
                    ForEach(PracticeMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle("Show word and meaning translations", isOn: $showTranslations)
            Toggle("Show example translations", isOn: $showExampleTranslation)
            Toggle("Auto-play example audio after the word", isOn: $autoPlayExampleAudio)

            VStack(alignment: .leading, spacing: 8) {
                Stepper("Word playback count: \(wordPlaybackCount)x", value: $wordPlaybackCount, in: 1...4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Playback gap")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", wordPlaybackDelay))s")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $wordPlaybackDelay, in: 0.4...2.4, step: 0.1)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    var geminiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Google Gemini API Key")
                .font(.headline)
            
            Text("Optional. If empty, word definitions fall back to Pollinations AI.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                SecureField("Enter Gemini Key (AIza...)", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)
                
                Button("Save") {
                    saveGeminiKey()
                }
            }
            
            Link("Get API Key from Google AI Studio", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                .font(.caption)
                .pointingCursor()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    var stabilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stability AI API Key")
                    .font(.headline)
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("High-quality image generation backup. If empty, uses free Pollinations AI.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                SecureField("Enter Stability Key (sk-...)", text: $stabilityKey)
                    .textFieldStyle(.roundedBorder)
                
                Button("Save") {
                    saveStabilityKey()
                }
            }
            
            Link("Get API Key from Stability AI", destination: URL(string: "https://platform.stability.ai/account/keys")!)
                .font(.caption)
                .pointingCursor()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    var actionsSection: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .pointingCursor()
        }
    }
}

// MARK: - Handlers

private extension SettingsView {
    func loadKeys() {
        do {
            geminiKey = try KeychainHelper.shared.read(for: KeychainHelper.geminiKey) ?? ""
            stabilityKey = try KeychainHelper.shared.read(for: KeychainHelper.stabilityKey) ?? ""
        } catch {
            presentFeedback(
                title: "Keychain Error",
                message: error.localizedDescription,
                style: .failure
            )
        }
    }
    
    func saveGeminiKey() {
        let trimmedKey = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        geminiKey = trimmedKey

        do {
            if trimmedKey.isEmpty {
                try KeychainHelper.shared.delete(for: KeychainHelper.geminiKey)
            } else {
                try KeychainHelper.shared.save(trimmedKey, for: KeychainHelper.geminiKey)
            }
            presentTransientFeedback(
                title: trimmedKey.isEmpty ? "Gemini Key Cleared" : "Gemini Key Saved",
                message: trimmedKey.isEmpty ? "Gemini fallback mode remains available." : "The Gemini API key was stored in the keychain.",
                style: .success
            )
        } catch {
            presentFeedback(
                title: "Gemini Save Failed",
                message: error.localizedDescription,
                style: .failure
            )
        }
    }
    
    func saveStabilityKey() {
        let trimmedKey = stabilityKey.trimmingCharacters(in: .whitespacesAndNewlines)
        stabilityKey = trimmedKey

        do {
            if trimmedKey.isEmpty {
                try KeychainHelper.shared.delete(for: KeychainHelper.stabilityKey)
            } else {
                try KeychainHelper.shared.save(trimmedKey, for: KeychainHelper.stabilityKey)
            }
            presentTransientFeedback(
                title: trimmedKey.isEmpty ? "Stability Key Cleared" : "Stability Key Saved",
                message: trimmedKey.isEmpty ? "Image generation will use the fallback provider." : "The Stability API key was stored in the keychain.",
                style: .success
            )
        } catch {
            presentFeedback(
                title: "Stability Save Failed",
                message: error.localizedDescription,
                style: .failure
            )
        }
    }

    func selectNewLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Storage Folder"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            self.isChangingStorageLocation = true
            self.feedback = nil

            Task(priority: .userInitiated) {
                do {
                    try repository.changeStorageLocation(to: url)
                    await MainActor.run {
                        self.isChangingStorageLocation = false
                        self.presentFeedback(
                            title: "Storage Updated",
                            message: "App data was moved to the new storage location.",
                            style: .success
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.isChangingStorageLocation = false
                        self.presentFeedback(
                            title: "Storage Move Failed",
                            message: error.localizedDescription,
                            style: .failure
                        )
                    }
                }
            }
        }
    }

    func presentFeedback(title: String, message: String, style: InlineFeedbackStyle) {
        withAnimation {
            feedback = InlineFeedback(title: title, message: message, style: style)
        }
    }

    func presentTransientFeedback(title: String, message: String, style: InlineFeedbackStyle) {
        presentFeedback(title: title, message: message, style: style)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation {
                if feedback?.title == title {
                    feedback = nil
                }
            }
        }
    }
}
