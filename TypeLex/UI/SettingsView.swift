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
        SectionCard {
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
    }

    var onboardingSection: some View {
        SectionCard {
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
    }

    var storageSection: some View {
        SectionCard {
            Text("Storage")
                .font(.headline)

            Text("Choose where books, CSV files, images, and audio are stored.")
                .font(.caption)
                .foregroundColor(.secondary)

            StorageLocationSummaryView(
                path: repository.storageDirectory.path,
                changeTitle: isChangingStorageLocation ? "Moving..." : "Change Location",
                buttonKind: .bordered,
                onChange: selectNewLocation
            )
            .allowsHitTesting(!isChangingStorageLocation)
            .opacity(isChangingStorageLocation ? 0.7 : 1)
        }
    }

    var practiceSection: some View {
        SectionCard {
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
    }
    
    var geminiSection: some View {
        SectionCard {
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
    }
    
    var stabilitySection: some View {
        SectionCard {
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
            presentInlineFeedback(
                $feedback,
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
            presentTransientInlineFeedback(
                $feedback,
                title: trimmedKey.isEmpty ? "Gemini Key Cleared" : "Gemini Key Saved",
                message: trimmedKey.isEmpty ? "Gemini fallback mode remains available." : "The Gemini API key was stored in the keychain.",
                style: .success
            )
        } catch {
            presentInlineFeedback(
                $feedback,
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
            presentTransientInlineFeedback(
                $feedback,
                title: trimmedKey.isEmpty ? "Stability Key Cleared" : "Stability Key Saved",
                message: trimmedKey.isEmpty ? "Image generation will use the fallback provider." : "The Stability API key was stored in the keychain.",
                style: .success
            )
        } catch {
            presentInlineFeedback(
                $feedback,
                title: "Stability Save Failed",
                message: error.localizedDescription,
                style: .failure
            )
        }
    }

    func selectNewLocation() {
        StorageLocationPicker.present { url in
            guard let url else { return }

            self.isChangingStorageLocation = true
            self.feedback = nil

            Task(priority: .userInitiated) {
                do {
                    try repository.changeStorageLocation(to: url)
                    await MainActor.run {
                        self.isChangingStorageLocation = false
                        presentInlineFeedback(
                            $feedback,
                            title: "Storage Updated",
                            message: "App data was moved to the new storage location.",
                            style: .success
                        )
                    }
                } catch {
                    await MainActor.run {
                        self.isChangingStorageLocation = false
                        presentInlineFeedback(
                            $feedback,
                            title: "Storage Move Failed",
                            message: error.localizedDescription,
                            style: .failure
                        )
                    }
                }
            }
        }
    }
}
