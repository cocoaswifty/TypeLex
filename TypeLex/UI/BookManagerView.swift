import SwiftUI

struct BookManagerView: View {
    @Environment(\.dismiss) var dismiss
    var repository: WordRepository
    
    @State private var newBookName: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            booksList
            
            actionsArea
        }
        .frame(minWidth: 450, minHeight: 500)
    }
}

// MARK: - Subviews

private extension BookManagerView {
    var header: some View {
        HStack {
            Text("Manage Word Books")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Button("Done") { dismiss() }
                .pointingCursor()
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    var booksList: some View {
        List {
            ForEach(repository.availableBooks, id: \.self) { bookName in
                BookRowView(
                    bookName: bookName,
                    isCurrent: bookName == repository.currentBookName,
                    onSelect: { repository.loadBook(name: bookName) },
                    onDelete: { repository.deleteBook(name: bookName) }
                )
            }
        }
        .listStyle(.inset)
    }
    
    var actionsArea: some View {
        VStack(spacing: 12) {
            if isCreating {
                creationField
            } else {
                newBookButton
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    var creationField: some View {
        HStack {
            TextField("New Book Name", text: $newBookName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createBook() }
            
            Button("Create") { createBook() }
                .disabled(newBookName.isEmpty)
                .pointingCursor()
            
            Button("Cancel") {
                isCreating = false
                newBookName = ""
            }
            .pointingCursor()
        }
    }
    
    var newBookButton: some View {
        HStack {
            Button(action: { isCreating = true }) {
                Label("New Book", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .pointingCursor()
            
            Spacer()
        }
    }
}

// MARK: - Handlers

private extension BookManagerView {
    func createBook() {
        guard !newBookName.isEmpty else { return }
        repository.createNewBook(name: newBookName)
        newBookName = ""
        isCreating = false
    }
}

// MARK: - Row View

struct BookRowView: View {
    let bookName: String
    let isCurrent: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "book.closed")
                .foregroundColor(.blue)
            
            Text(bookName)
                .fontWeight(isCurrent ? .bold : .regular)
            
            if isCurrent {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            if bookName != "Default" && !isCurrent {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .pointingCursor()
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCurrent {
                onSelect()
            }
        }
        .pointingCursor()
    }
}
