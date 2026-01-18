import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    
    @State private var geminiKey: String = ""
    @State private var stabilityKey: String = ""
    @State private var isGeminiSaved: Bool = false
    @State private var isStabilitySaved: Bool = false
    
    // UI Scale setting (persisted)
    @AppStorage("userUIScale") private var userUIScale: Double = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            uiScaleSection
            geminiSection
            stabilitySection
            
            actionsSection
        }
        .padding(30)
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
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .disabled(abs(userUIScale - 1.0) < 0.01)
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
            
            Text("Required for AI word generation (definitions & sentences).")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                SecureField("Enter Gemini Key (AIza...)", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)
                
                Button("Save") {
                    saveGeminiKey()
                }
                .disabled(geminiKey.isEmpty)
            }
            
            if isGeminiSaved {
                Text("✅ Gemini Key saved")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
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
                .disabled(stabilityKey.isEmpty)
            }
            
            if isStabilitySaved {
                Text("✅ Stability Key saved")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
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
            .buttonStyle(.borderedProminent)
            .pointingCursor()
        }
    }
}

// MARK: - Handlers

private extension SettingsView {
    func loadKeys() {
        if let key = KeychainHelper.shared.read(for: KeychainHelper.geminiKey) {
            geminiKey = key
        }
        if let key = KeychainHelper.shared.read(for: KeychainHelper.stabilityKey) {
            stabilityKey = key
        }
    }
    
    func saveGeminiKey() {
        guard !geminiKey.isEmpty else { return }
        KeychainHelper.shared.save(geminiKey, for: KeychainHelper.geminiKey)
        withAnimation { isGeminiSaved = true }
        
        // Auto hide success message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { isGeminiSaved = false }
        }
    }
    
    func saveStabilityKey() {
        guard !stabilityKey.isEmpty else { return }
        KeychainHelper.shared.save(stabilityKey, for: KeychainHelper.stabilityKey)
        withAnimation { isStabilitySaved = true }
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { isStabilitySaved = false }
        }
    }
}

