import SwiftUI

struct PracticeCardView: View {
    var vm: PracticeViewModel
    @Binding var showLargeImage: Bool
    var scale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 24 * scale) {
            // 1. 圖片區域 (Visual Anchor)
            WordImageView(
                entry: vm.currentEntry,
                repository: vm.repository,
                isRegenerating: vm.isRegeneratingImage,
                onRegenerate: { vm.regenerateCurrentImage() },
                showLargeImage: $showLargeImage,
                scale: scale
            )
            
            // 2. 釋義區域 (Prompt Area)
            definitionSection
            
            VStack(spacing: 0) {
                // Translation
                if let translation = vm.currentEntry.translation {
                    Text(translation)
                        .font(.system(size: 28 * scale, weight: .regular))
                }

                // 3. 打字互動區 (Interaction Area)
                TypingDisplayView(
                    typedPrefix: vm.engine.typedPrefix,
                    remainingSuffix: vm.engine.remainingSuffix,
                    isFinished: vm.engine.isFinished,
                    lastInputWasError: vm.engine.lastInputWasError,
                    scale: scale,
                    onSpeak: { vm.speakCurrentWord() }
                )

                // Metadata Chips
                metadataSection
            }
            
            // 4. 單字資訊與例句 (Context Footer)
            exampleSection
        }
        .padding(.vertical, 32 * scale)
    }
}

// MARK: - Subviews

private extension PracticeCardView {
    var definitionSection: some View {
        VStack(spacing: 8 * scale) {
            if let meaningTranslation = vm.currentEntry.meaningTranslation {
                Text(meaningTranslation)
                    .font(.system(size: 16 * scale))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 8 * scale) {
                Text(vm.currentEntry.meaning)
                    .font(.system(size: 22 * scale, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .onTapGesture { vm.speakMeaning() }
                    .pointingCursor()
                
                if vm.currentEntry.soundMeaningPath != nil || !vm.currentEntry.meaning.isEmpty {
                    Button(action: { vm.speakMeaning() }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 14 * scale))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                }
            }
        }
        .padding(.horizontal, 24 * scale)
        .contextMenu {
            Button(action: { vm.regenerateCurrentText() }) {
                Label("Regenerate Definition", systemImage: "text.bubble")
            }
        }
    }
    
    var metadataSection: some View {
        HStack(spacing: 8 * scale) {
            if let phonetic = vm.currentEntry.phonetic {
                Text("[\(phonetic)]")
                    .font(.system(size: 20 * scale, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .onTapGesture { vm.speakCurrentWord() }
                    .pointingCursor()
            }

            Button(action: { vm.speakCurrentWord() }) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 14 * scale))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
        .padding(.horizontal, 20 * scale)
        .padding(.vertical, 8 * scale)
    }
    
    var exampleSection: some View {
        VStack(spacing: 16 * scale) {
            Divider().frame(height: 16 * scale)

            if let example = vm.currentEntry.example {
                VStack(spacing: 4 * scale) {
                    HStack(spacing: 8 * scale) {
                        Text(example)
                            .font(.system(size: 24 * scale, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(.primary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .onTapGesture { vm.speakExample() }
                            .pointingCursor()
                        
                        Button(action: { vm.speakExample() }) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 14 * scale))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .pointingCursor()
                    }
                    
                    if let translation = vm.currentEntry.exampleTranslation {
                        Text(translation)
                            .font(.system(size: 18 * scale))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32 * scale)
            }
        }
    }
}
