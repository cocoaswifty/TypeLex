import SwiftUI

struct WordRowView: View {
    let entry: WordEntry
    let repository: WordRepository
    private let speechService: SpeechPlaying = SpeechService.shared
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            wordInfoSection
            
            Spacer()
            
            audioButtonsSection
                .padding(.trailing, 8)
            
            statusIconsSection
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(entry.isFavorite ? "Remove Favorite" : "Mark Favorite") {
                toggleFavorite()
            }

            Button("Reset Progress") {
                repository.resetReviewProgress(for: Set([entry.id]))
            }

            Divider()

            Button("Delete", role: .destructive) {
                deleteWord()
            }
        }
    }
}

private extension WordRowView {
    var wordInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.word)
                    .font(.headline)
                    .monospaced()
                
                if let translation = entry.translation {
                    Text(translation)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                if let phonetic = entry.phonetic {
                    Text("[\(phonetic)]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.meaning)
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.8))
                
                if let meaningTranslation = entry.meaningTranslation {
                    Text(meaningTranslation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    var audioButtonsSection: some View {
        HStack(spacing: 4) {
            if entry.soundPath != nil || !entry.word.isEmpty {
                AudioButton(icon: "speaker.wave.2.fill", color: .blue) {
                    playAudio(type: .word)
                }
            }
            if entry.soundMeaningPath != nil || !entry.meaning.isEmpty {
                AudioButton(icon: "speaker.wave.2", color: .secondary) {
                    playAudio(type: .meaning)
                }
            }
            if let example = entry.example, (entry.soundExamplePath != nil || !example.isEmpty) {
                AudioButton(icon: "text.bubble", color: .secondary) {
                    playAudio(type: .example)
                }
            }
        }
    }
    
    var statusIconsSection: some View {
        HStack(spacing: 8) {
            if (entry.mistakeCount ?? 0) > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(entry.mistakeCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .help("Mistakes recorded")
            }
            
            favoriteButton
            
            Button(role: .destructive, action: deleteWord) {
                Image(systemName: "trash")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Delete word")
            .pointingCursor()
        }
    }
    
    enum AudioType { case word, meaning, example }

    var favoriteButton: some View {
        Button(action: toggleFavorite) {
            Image(systemName: entry.isFavorite ? "star.fill" : "star")
                .foregroundColor(entry.isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .help(entry.isFavorite ? "Remove favorite" : "Mark favorite")
        .pointingCursor()
    }
    
    func playAudio(type: AudioType) {
        let path: String?
        let fallbackText: String
        
        switch type {
        case .word:
            path = entry.soundPath
            fallbackText = entry.word
        case .meaning:
            path = entry.soundMeaningPath
            fallbackText = entry.meaning
        case .example:
            path = entry.soundExamplePath
            fallbackText = entry.example ?? ""
        }
        
        if let path = path {
            let url = repository.resolveFileURL(for: path)
            if FileManager.default.fileExists(atPath: url.path) {
                speechService.playAudio(at: url)
                return
            }
        }
        speechService.speak(fallbackText)
    }
    
    func deleteWord() {
        if let index = repository.words.firstIndex(where: { $0.id == entry.id }) {
            repository.deleteWords(at: IndexSet(integer: index))
        }
    }

    func toggleFavorite() {
        repository.toggleFavorite(for: entry.id)
    }
}

struct AudioButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .foregroundColor(color)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Play audio")
        .pointingCursor()
    }
}
