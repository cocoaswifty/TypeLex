import Foundation
import OSLog

struct WordRepositoryMigration {
    let fileManager: FileManager
    let storageDirectory: URL
    let extensionName: String

    func migrateFileStructure() {
        migrateJSONToCSV()

        do {
            let files = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            let csvFiles = files.filter { $0.pathExtension == extensionName }

            for csvURL in csvFiles {
                let bookName = csvURL.deletingPathExtension().lastPathComponent
                let bookFolder = storageDirectory.appendingPathComponent(bookName)
                let mediaFolder = bookFolder.appendingPathComponent("media")
                let targetCSV = bookFolder.appendingPathComponent("\(bookName).\(extensionName)")

                if !fileManager.fileExists(atPath: mediaFolder.path) {
                    try fileManager.createDirectory(at: mediaFolder, withIntermediateDirectories: true, attributes: nil)
                }

                if let content = try? String(contentsOf: csvURL, encoding: .utf8) {
                    var words = CSVHelper.decode(content)

                    for index in words.indices {
                        if let imagePath = words[index].localImagePath, !imagePath.isEmpty, migrateMediaFile(filename: imagePath, to: mediaFolder), !imagePath.contains("/") {
                            words[index].localImagePath = "media/\(imagePath)"
                        }

                        if let soundPath = words[index].soundPath, migrateMediaFile(filename: soundPath, to: mediaFolder), !soundPath.contains("/") {
                            words[index].soundPath = "media/\(soundPath)"
                        }

                        if let meaningPath = words[index].soundMeaningPath, migrateMediaFile(filename: meaningPath, to: mediaFolder), !meaningPath.contains("/") {
                            words[index].soundMeaningPath = "media/\(meaningPath)"
                        }

                        if let examplePath = words[index].soundExamplePath, migrateMediaFile(filename: examplePath, to: mediaFolder), !examplePath.contains("/") {
                            words[index].soundExamplePath = "media/\(examplePath)"
                        }
                    }

                    let newContent = CSVHelper.encode(words)
                    try newContent.write(to: targetCSV, atomically: true, encoding: .utf8)
                    try fileManager.removeItem(at: csvURL)
                }
            }
        } catch {
            AppLogger.migration.warning("File structure migration failed: \(error.localizedDescription)")
        }
    }

    private func migrateMediaFile(filename: String, to folder: URL) -> Bool {
        let name = filename.components(separatedBy: "/").last ?? filename
        let oldURL = storageDirectory.appendingPathComponent(name)
        let targetURL = folder.appendingPathComponent(name)

        guard fileManager.fileExists(atPath: oldURL.path) else { return false }

        do {
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.moveItem(at: oldURL, to: targetURL)
            return true
        } catch {
            AppLogger.migration.error("Failed to move media \(filename, privacy: .public): \(error.localizedDescription)")
            return false
        }
    }

    private func migrateJSONToCSV() {
        do {
            let files = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            for url in jsonFiles {
                let name = url.deletingPathExtension().lastPathComponent

                if let data = try? Data(contentsOf: url),
                   let oldWords = try? JSONDecoder().decode([WordEntry].self, from: data) {
                    let csvString = CSVHelper.encode(oldWords)
                    let csvURL = storageDirectory.appendingPathComponent(name).appendingPathExtension("csv")
                    try csvString.write(to: csvURL, atomically: true, encoding: .utf8)
                    try fileManager.removeItem(at: url)
                }
            }
        } catch {
            AppLogger.migration.warning("JSON to CSV migration failed: \(error.localizedDescription)")
        }
    }
}
