import Foundation

/// Handles importing of vocabulary libraries from external folders.
/// Expected Format:
/// - Folder/
///   - *.csv (Word list with columns: Word,IPA,Translation,Meaning,Meaning_Translation,Example,Example_Translation,Image,Sound,Sound_Meaning,Sound_Example)
///   - media/ (Contains images and sound files)
class LibraryImporter {
    
    enum ImportError: Error {
        case fileNotFound
        case csvNotFound
        case invalidCSVContent
        case securityAccessRequired
    }
    
    /// Imports a library from a folder URL or a ZIP file URL
    static func importLibrary(from inputURL: URL, to targetDirectory: URL) throws -> [WordEntry] {
        let fileManager = FileManager.default
        var processingURL = inputURL
        var isTempDirectory = false
        
        // Handle ZIP files
        if inputURL.pathExtension.lowercased() == "zip" {
            print("📦 Detected ZIP file. Extracting...")
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try unzip(file: inputURL, to: tempDir)
            processingURL = tempDir
            isTempDirectory = true
        }
        
        // Clean up temp directory if needed
        defer {
            if isTempDirectory {
                try? fileManager.removeItem(at: processingURL)
                print("🧹 Cleaned up temp directory: \(processingURL.path)")
            }
        }

        // Handle security-scoped resources if needed
        let accessing = processingURL.startAccessingSecurityScopedResource()
        defer { if accessing { processingURL.stopAccessingSecurityScopedResource() } }
        
        // 1. Find all CSV files recursively
        var csvURLs: [URL] = []
        if let enumerator = fileManager.enumerator(at: processingURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "csv" {
                    csvURLs.append(url)
                }
            }
        }
        
        if csvURLs.isEmpty {
            // Check if it's a direct CSV file (only if not a zip extraction result, though zip extraction results are folders)
            if !isTempDirectory && processingURL.pathExtension.lowercased() == "csv" {
                csvURLs.append(processingURL)
            } else {
                print("❌ No CSV files found in: \(processingURL.path)")
                throw ImportError.csvNotFound
            }
        }
        
        var allWords: [WordEntry] = []
        
        print("🔍 Found \(csvURLs.count) CSV files: \(csvURLs.map { $0.lastPathComponent })")
        
        for csvURL in csvURLs {
            do {
                let wordsFromFile = try importWords(from: csvURL, libraryRoot: processingURL, to: targetDirectory)
                print("✅ Imported \(wordsFromFile.count) words from \(csvURL.lastPathComponent)")
                allWords.append(contentsOf: wordsFromFile)
            } catch {
                print("⚠️ Failed to import from \(csvURL.lastPathComponent): \(error)")
            }
        }
        
        guard !allWords.isEmpty else {
            print("❌ No words imported from any CSV file.")
            throw ImportError.invalidCSVContent
        }
        return allWords
    }
    
    /// Unzips a file using the system 'unzip' command (Requires non-sandboxed app or appropriate entitlements)
    private static func unzip(file sourceURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        // -o: overwrite existing (shouldn't happen in new temp dir but safe to add)
        // -q: quiet mode (CRITICAL: prevents pipe buffer deadlock on large archives)
        // -d: destination directory
        process.arguments = ["-o", "-q", sourceURL.path, "-d", destinationURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        print("⚡️ Executing unzip command...")
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Unzip failed: \(output)")
            throw ImportError.invalidCSVContent 
        }
        print("✅ Unzip successful to: \(destinationURL.path)")
    }
    
    private static func importWords(from csvURL: URL, libraryRoot: URL, to targetDirectory: URL) throws -> [WordEntry] {
        let fileManager = FileManager.default
        print("📂 Processing CSV: \(csvURL.lastPathComponent)")
        
        // Try multiple encodings
        var csvContent: String = ""
        let encodings: [String.Encoding] = [.utf8, .unicode, .utf16, .japaneseEUC, .isoLatin1]
        
        var loadError: Error?
        for encoding in encodings {
            do {
                csvContent = try String(contentsOf: csvURL, encoding: encoding)
                if !csvContent.isEmpty {
                    loadError = nil
                    print("📄 Successfully read CSV content with encoding: \(encoding)")
                    break 
                }
            } catch {
                loadError = error
            }
        }
        
        if csvContent.isEmpty, let error = loadError {
            print("❌ Failed to read CSV content: \(error)")
            throw error
        }
        
        print("🔍 Content Preview (first 100 chars): \(csvContent.prefix(100))")
        print("🔍 Content Scalars (first 50): \(csvContent.prefix(50).unicodeScalars.map { $0.value })")
        
        let rows = CSVHelper.parseCSV(csvContent)
        print("📊 Parsed \(rows.count) rows (including header)")
        guard rows.count > 1 else { return [] }
        
        // 3. Parse Headers (More robust cleaning)
        let headers = rows[0]
        var indexMap: [String: Int] = [:]
        let sensitiveChars = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")) // Including BOM
        
        for (i, h) in headers.enumerated() {
            let cleanHeader = h.trimmingCharacters(in: sensitiveChars).lowercased()
            indexMap[cleanHeader] = i
        }
        print("🏷 Headers found: \(indexMap.keys)")
        
        var words: [WordEntry] = []
        let mediaDirectory = libraryRoot.appendingPathComponent("media")
        
        func copyMediaFile(named filename: String, currentCSVDir: URL) -> String? {
            let cleanName = filename.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanName.isEmpty else { return nil }
            
            let possibleSources = [
                mediaDirectory.appendingPathComponent(cleanName),
                currentCSVDir.appendingPathComponent("media").appendingPathComponent(cleanName),
                currentCSVDir.appendingPathComponent(cleanName)
            ]
            
            let destURL = targetDirectory.appendingPathComponent(cleanName)
            
            for sourceURL in possibleSources {
                if fileManager.fileExists(atPath: sourceURL.path) {
                    if !fileManager.fileExists(atPath: destURL.path) {
                        try? fileManager.copyItem(at: sourceURL, to: destURL)
                    }
                    return cleanName
                }
            }
            return nil
        }
        
        let currentCSVDir = csvURL.deletingLastPathComponent()
        
        // 4. Parse Rows
        for i in 1..<rows.count {
            let fields = rows[i]
            if fields.isEmpty { continue }
            // Some CSVs have trailing empty fields, check if the first few important ones exist
            if fields.count < 1 || fields.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            
            func val(_ keys: [String]) -> String {
                for key in keys {
                    if let idx = indexMap[key.lowercased()], idx < fields.count {
                        return fields[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                return ""
            }
            
            let word = val(["Word", "word", "單字", "Text", "Name"])
            if word.isEmpty {
                 print("⚠️ Row \(i): Skipped because 'Word' field is empty. Fields: \(fields)")
                 continue
            }
            
            let ipa = val(["IPA", "phonetic", "音標", "Pronunciation"])
            let translation = val(["Translation", "翻譯", "意思"])
            let meaning = val(["Meaning", "Definition", "釋義"])
            let meaningTranslation = val(["Meaning_Translation", "meaningTranslation", "釋義翻譯"])
            let example = val(["Example", "example", "例句", "Sentence"])
            let exampleTranslation = val(["Example_Translation", "exampleTranslation", "例句翻譯", "Sentence_Translation"])
            
            let imageFilename = val(["Image", "imageName", "圖片", "Picture", "Images"])
            let soundFilename = val(["Sound", "soundPath", "發音", "Audio", "Voice"])
            let soundMeaningFilename = val(["Sound_Meaning", "soundMeaningPath"])
            let soundExampleFilename = val(["Sound_Example", "soundExamplePath"])
            
            let localImage = copyMediaFile(named: imageFilename, currentCSVDir: currentCSVDir)
            let localSound = copyMediaFile(named: soundFilename, currentCSVDir: currentCSVDir)
            let localSoundMeaning = copyMediaFile(named: soundMeaningFilename, currentCSVDir: currentCSVDir)
            let localSoundExample = copyMediaFile(named: soundExampleFilename, currentCSVDir: currentCSVDir)
            
            let entry = WordEntry(
                word: word,
                phonetic: ipa.isEmpty ? nil : ipa,
                translation: translation.isEmpty ? nil : translation,
                meaning: meaning.isEmpty ? translation : meaning, // Fallback to translation if meaning is empty
                meaningTranslation: meaningTranslation.isEmpty ? nil : meaningTranslation,
                example: example.isEmpty ? nil : example,
                exampleTranslation: exampleTranslation.isEmpty ? nil : exampleTranslation,
                imageName: nil,
                localImagePath: localImage,
                soundPath: localSound,
                soundMeaningPath: localSoundMeaning,
                soundExamplePath: localSoundExample,
                isFavorite: false,
                mistakeCount: 0
            )
            words.append(entry)
        }
        
        return words
    }
}
