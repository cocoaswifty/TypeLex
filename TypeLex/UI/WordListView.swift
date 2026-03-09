import SwiftUI

struct WordListView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    
    @State private var filter = WordListFilter()
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
        .onChange(of: filter.searchText) {
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
        filter.visibleWords(from: repository.words)
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

                TextField("Search words, meanings, translations, examples", text: $filter.searchText)
                    .textFieldStyle(.plain)

                if !filter.searchText.isEmpty {
                    Button {
                        filter.searchText = ""
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

            Picker("Sort", selection: $filter.sortOption) {
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
                    presentInlineFeedback(
                        $feedback,
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
            Image(systemName: filter.searchText.isEmpty ? "text.magnifyingglass" : "magnifyingglass.circle")
                .font(.system(size: 42))
                .foregroundColor(.secondary)

            Text(filter.searchText.isEmpty ? "No words in this book" : "No matches found")
                .font(.headline)

            Text(filter.searchText.isEmpty
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
        if filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            presentInlineFeedback(
                $feedback,
                title: "Words Moved",
                message: "Moved \(selectedCount) words to \(bookName).",
                style: .success
            )
        } catch {
            presentInlineFeedback(
                $feedback,
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
