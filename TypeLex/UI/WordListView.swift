import SwiftUI

struct WordListView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    
    @State private var searchText: String = ""
    @State private var sortOption: WordListSortOption = .alphabetical
    @State private var selectedWordIDs = Set<String>()
    @State private var feedback: InlineFeedback?
    
    var body: some View {
        VStack(spacing: 0) {
            header

            if let feedback {
                InlineFeedbackView(feedback: feedback) {
                    self.feedback = nil
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            filterBar
            batchActionBar
            
            if visibleWords.isEmpty {
                emptyState
            } else {
                List(selection: $selectedWordIDs) {
                    ForEach(visibleWords) { entry in
                        WordRowView(entry: entry, repository: repository)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.inset)
            }
            
            footer
        }
        .frame(minWidth: 500, minHeight: 600)
        .onChange(of: searchText) {
            syncSelectionToVisibleWords()
        }
        .onChange(of: repository.words.map(\.id)) {
            syncSelection()
        }
    }
}

// MARK: - Subviews

private extension WordListView {
    var visibleWords: [WordEntry] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredWords: [WordEntry]
        
        if trimmedQuery.isEmpty {
            filteredWords = repository.words
        } else {
            filteredWords = repository.words.filter { entry in
                entry.word.localizedCaseInsensitiveContains(trimmedQuery)
                    || (entry.translation?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                    || entry.meaning.localizedCaseInsensitiveContains(trimmedQuery)
                    || (entry.example?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            }
        }
        
        return sortOption.sorted(using: filteredWords)
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Word List")
                    .font(.title2)
                    .fontWeight(.bold)

                if hasSelection {
                    Text("\(selectedWordIDs.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(summaryText)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search words, meanings, translations, examples", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .pointingCursor()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(10)

            Picker("Sort", selection: $sortOption) {
                ForEach(WordListSortOption.allCases) { option in
                    Label(option.title, systemImage: option.icon)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 190)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    var batchActionBar: some View {
        if hasSelection {
            HStack(spacing: 10) {
                Label("\(selectedWordIDs.count) selected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Favorite") {
                    repository.setFavorite(true, for: selectedWordIDs)
                    syncSelection()
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()

                Button("Unfavorite") {
                    repository.setFavorite(false, for: selectedWordIDs)
                    syncSelection()
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()

                Button("Reset Progress") {
                    repository.resetReviewProgress(for: selectedWordIDs)
                    syncSelection()
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()

                if !destinationBooks.isEmpty {
                    Menu {
                        ForEach(destinationBooks, id: \.self) { bookName in
                            Button(bookName) {
                                moveSelection(to: bookName)
                            }
                        }
                    } label: {
                        Label("Move to Book", systemImage: "books.vertical")
                    }
                    .pointingCursor()
                }

                Button("Delete", role: .destructive) {
                    repository.deleteWords(withIDs: selectedWordIDs)
                    selectedWordIDs.removeAll()
                    feedback = InlineFeedback(
                        title: "Words Deleted",
                        message: "Removed the selected words from this book.",
                        style: .success
                    )
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()

                Button("Clear") {
                    selectedWordIDs.removeAll()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                .pointingCursor()
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: searchText.isEmpty ? "text.magnifyingglass" : "magnifyingglass.circle")
                .font(.system(size: 42))
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ? "No words in this book" : "No matches found")
                .font(.headline)

            Text(searchText.isEmpty
                 ? "Import a library or add words to start building this list."
                 : "Try a different keyword or clear the current search.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    var footer: some View {
        HStack {
            Text("Tip: Command-click to select multiple words for batch actions.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if !visibleWords.isEmpty {
                Button(allVisibleSelected ? "Clear Visible" : "Select Visible") {
                    toggleVisibleSelection()
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.secondary)
                .pointingCursor()
            }

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .pointingCursor()
        }
        .padding()
    }

    var summaryText: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(repository.words.count) words"
        }
        return "\(visibleWords.count) of \(repository.words.count) words"
    }

    var hasSelection: Bool {
        !selectedWordIDs.isEmpty
    }

    var destinationBooks: [String] {
        repository.availableBooks.filter { $0 != repository.currentBookName }
    }

    var allVisibleSelected: Bool {
        let visibleIDs = Set(visibleWords.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedWordIDs)
    }
}

// MARK: - Handlers

private extension WordListView {
    func deleteItems(offsets: IndexSet) {
        let visibleIDs = offsets.map { visibleWords[$0].id }
        let actualOffsets = IndexSet(
            repository.words.enumerated()
                .compactMap { visibleIDs.contains($0.element.id) ? $0.offset : nil }
        )
        repository.deleteWords(at: actualOffsets)
        syncSelection()
    }

    func syncSelection() {
        let currentIDs = Set(repository.words.map(\.id))
        selectedWordIDs = selectedWordIDs.intersection(currentIDs)
    }

    func syncSelectionToVisibleWords() {
        let visibleIDs = Set(visibleWords.map(\.id))
        selectedWordIDs = selectedWordIDs.intersection(visibleIDs)
    }

    func moveSelection(to bookName: String) {
        let selectedCount = selectedWordIDs.count

        do {
            try repository.moveWords(withIDs: selectedWordIDs, toBookNamed: bookName)
            selectedWordIDs.removeAll()
            feedback = InlineFeedback(
                title: "Words Moved",
                message: "Moved \(selectedCount) words to \(bookName).",
                style: .success
            )
        } catch {
            feedback = InlineFeedback(
                title: "Move Failed",
                message: error.localizedDescription,
                style: .failure
            )
        }
    }

    func toggleVisibleSelection() {
        let visibleIDs = Set(visibleWords.map(\.id))
        if allVisibleSelected {
            selectedWordIDs.subtract(visibleIDs)
        } else {
            selectedWordIDs.formUnion(visibleIDs)
        }
    }
}

// MARK: - Row View

struct WordRowView: View {
    let entry: WordEntry
    let repository: WordRepository
    private let speechService = SpeechService.shared
    
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
            
            // Delete Button
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

// MARK: - Components

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
        .pointingCursor()
    }
}

private enum WordListSortOption: String, CaseIterable, Identifiable {
    case alphabetical
    case recentReview
    case mistakes
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabetical: return "Alphabetical"
        case .recentReview: return "Recently Reviewed"
        case .mistakes: return "Mistakes"
        case .favorites: return "Favorites First"
        }
    }

    var icon: String {
        switch self {
        case .alphabetical: return "textformat"
        case .recentReview: return "clock.arrow.circlepath"
        case .mistakes: return "exclamationmark.triangle"
        case .favorites: return "star"
        }
    }

    func sorted(using words: [WordEntry]) -> [WordEntry] {
        words.sorted { lhs, rhs in
            switch self {
            case .alphabetical:
                return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
            case .recentReview:
                return (lhs.lastReviewedAt ?? .distantPast) > (rhs.lastReviewedAt ?? .distantPast)
            case .mistakes:
                let leftMistakes = lhs.mistakeCount ?? 0
                let rightMistakes = rhs.mistakeCount ?? 0
                if leftMistakes == rightMistakes {
                    return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
                }
                return leftMistakes > rightMistakes
            case .favorites:
                if lhs.isFavorite == rhs.isFavorite {
                    return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
                }
                return lhs.isFavorite && !rhs.isFavorite
            }
        }
    }
}
