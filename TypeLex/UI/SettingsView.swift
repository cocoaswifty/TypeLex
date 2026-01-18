import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    
    @State private var geminiKey: String = ""
    @State private var stabilityKey: String = ""
    @State private var isGeminiSaved: Bool = false
    @State private var isStabilitySaved: Bool = false
    @State private var isCacheCleared: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            geminiSection
            stabilitySection
            maintenanceSection
            
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
    var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Maintenance")
                .font(.headline)
            
            Text("Clear temporary files and network caches. Useful if you experience issues.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Clear App Cache") {
                    clearAppCache()
                }
                
                if isCacheCleared {
                    Text("✅ Cache Cleared. Please restart.")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
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
    
    func clearAppCache() {
        // 1. Clear URL Cache
        URLCache.shared.removeAllCachedResponses()
        
        // 2. Clear Temporary Directory (safely)
        let fileManager = FileManager.default
        let tmpDir = fileManager.temporaryDirectory
        
        do {
            let tmpFiles = try fileManager.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
            for file in tmpFiles {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            print("⚠️ Failed to list temp files: \(error)")
        }
        
        withAnimation { isCacheCleared = true }
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation { isCacheCleared = false }
        }
    }
}
