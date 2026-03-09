import Foundation

struct WordRepositoryStorage {
    let fileManager: FileManager
    let storageDirectory: URL
    let extensionName: String

    func refreshAvailableBooks() throws -> [String] {
        let urls = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )

        var books: [String] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let name = url.lastPathComponent
            let csvURL = bookCSVURL(named: name)
            if fileManager.fileExists(atPath: csvURL.path) {
                books.append(name)
            }
        }

        return books.sorted()
    }

    func moveAllContent(from source: URL, to destination: URL) throws {
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        let files = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )

        for file in files {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: file.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let name = file.lastPathComponent
            let csvURL = file.appendingPathComponent("\(name).\(extensionName)")
            guard fileManager.fileExists(atPath: csvURL.path) else { continue }

            let targetURL = destination.appendingPathComponent(name)
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }

            try fileManager.moveItem(at: file, to: targetURL)
        }
    }

    func saveWords(_ words: [WordEntry], toBookNamed bookName: String) throws {
        let csvString = CSVHelper.encode(words)
        try csvString.write(to: bookCSVURL(named: bookName), atomically: true, encoding: .utf8)
    }

    @discardableResult
    func ensureBookExists(named bookName: String) throws -> Bool {
        let mediaURL = bookMediaFolderURL(named: bookName)
        let fileURL = bookCSVURL(named: bookName)

        try fileManager.createDirectory(at: mediaURL, withIntermediateDirectories: true)

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            return false
        }

        let header = CSVHelper.header + "\n"
        try header.write(to: fileURL, atomically: true, encoding: .utf8)
        return true
    }

    func loadWords(fromBookNamed bookName: String) throws -> [WordEntry] {
        let content = try String(contentsOf: bookCSVURL(named: bookName), encoding: .utf8)
        return CSVHelper.decode(content)
    }

    func loadReviewEvents(fromBookNamed bookName: String) -> [ReviewEvent] {
        let url = bookReviewEventsURL(named: bookName)
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ReviewEvent].self, from: data)
        } catch {
            print("⚠️ Failed to load review events: \(error)")
            return []
        }
    }

    func saveReviewEvents(_ reviewEvents: [ReviewEvent], toBookNamed bookName: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(reviewEvents)
        try data.write(to: bookReviewEventsURL(named: bookName), options: .atomic)
    }

    func removeMediaAssets(for entry: WordEntry, inBookNamed bookName: String) {
        if let imagePath = entry.localImagePath {
            let url = fileURL(for: imagePath, inBookNamed: bookName)
            try? fileManager.removeItem(at: url)
        }
    }

    func copyMediaAssets(for entry: WordEntry, fromBookNamed sourceBookName: String, toBookNamed destinationBookName: String) throws {
        let relativePaths = [entry.localImagePath, entry.soundPath, entry.soundMeaningPath, entry.soundExamplePath]
            .compactMap { $0 }
            .filter { !$0.hasPrefix("/") }

        for relativePath in relativePaths {
            let sourceURL = bookFolderURL(named: sourceBookName).appendingPathComponent(relativePath)
            let destinationURL = bookFolderURL(named: destinationBookName).appendingPathComponent(relativePath)

            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }

            let destinationFolder = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: destinationFolder.path) {
                try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            }

            if !fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }
    }

    func fileURL(for relativePath: String, inBookNamed bookName: String) -> URL {
        if relativePath.hasPrefix("/") {
            return URL(fileURLWithPath: relativePath)
        }

        return bookFolderURL(named: bookName).appendingPathComponent(relativePath)
    }

    func bookFolderURL(named name: String) -> URL {
        storageDirectory.appendingPathComponent(name)
    }

    func bookCSVURL(named name: String) -> URL {
        bookFolderURL(named: name).appendingPathComponent("\(name).\(extensionName)")
    }

    func bookMediaFolderURL(named name: String) -> URL {
        bookFolderURL(named: name).appendingPathComponent("media")
    }

    func bookReviewEventsURL(named name: String) -> URL {
        bookFolderURL(named: name).appendingPathComponent("review-events.json")
    }
}
