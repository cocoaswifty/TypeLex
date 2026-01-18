import SwiftUI

struct PracticeCardView: View {
    var vm: PracticeViewModel
    @Binding var showLargeImage: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // 1. 圖片區域 (Visual Anchor)
            WordImageView(
                entry: vm.currentEntry,
                repository: vm.repository,
                isRegenerating: vm.isRegeneratingImage,
                onRegenerate: { vm.regenerateCurrentImage() },
                showLargeImage: $showLargeImage
            )
            
            // 2. 釋義區域 (Prompt Area)
            definitionSection
            
            VStack(spacing: 0) {
                // Translation
                if let translation = vm.currentEntry.translation {
                    Text(translation)
                        .font(.title)
                }

                // 3. 打字互動區 (Interaction Area)
                TypingDisplayView(
                    typedPrefix: vm.engine.typedPrefix,
                    remainingSuffix: vm.engine.remainingSuffix,
                    isFinished: vm.engine.isFinished,
                    lastInputWasError: vm.engine.lastInputWasError,
                    onSpeak: { vm.speakCurrentWord() }
                )

                // Metadata Chips
                metadataSection
            }
            
            // 4. 單字資訊與例句 (Context Footer)
            exampleSection
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Subviews

private extension PracticeCardView {
    var definitionSection: some View {
        VStack(spacing: 8) {
            if let meaningTranslation = vm.currentEntry.meaningTranslation {
                Text(meaningTranslation)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 8) {
                Text(vm.currentEntry.meaning)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .onTapGesture { vm.speakMeaning() }
                    .pointingCursor()
                
                if vm.currentEntry.soundMeaningPath != nil || !vm.currentEntry.meaning.isEmpty {
                    Button(action: { vm.speakMeaning() }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                }
            }
        }
        .padding(.horizontal, 24)
        .contextMenu {
            Button(action: { vm.regenerateCurrentText() }) {
                Label("Regenerate Definition", systemImage: "text.bubble")
            }
        }
    }
    
    var metadataSection: some View {
        HStack(spacing: 8) {
            if let phonetic = vm.currentEntry.phonetic {
                Text("[\(phonetic)]")
                    .font(.system(size: 20, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .onTapGesture { vm.speakCurrentWord() }
                    .pointingCursor()
            }

            Button(action: { vm.speakCurrentWord() }) {
                Image(systemName: "speaker.wave.2")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    var exampleSection: some View {
        VStack(spacing: 16) {
            Divider().frame(height: 16)

            if let example = vm.currentEntry.example {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text(example)
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.primary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .onTapGesture { vm.speakExample() }
                            .pointingCursor()
                        
                        Button(action: { vm.speakExample() }) {
                            Image(systemName: "speaker.wave.2")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .pointingCursor()
                    }
                    
                    if let translation = vm.currentEntry.exampleTranslation {
                        Text(translation)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }
}
