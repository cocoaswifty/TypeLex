import Foundation
import SwiftUI // For possible Image usage if needed, but Foundation is enough for logic

struct CSVHelper {
    static let header = "word,phonetic,translation,meaning,meaningTranslation,example,exampleTranslation,imageName,localImagePath,soundPath,soundMeaningPath,soundExamplePath,isFavorite,mistakeCount"
    
    static func encode(_ words: [WordEntry]) -> String {
        var result = header + "\n"
        for word in words {
            let row = [
                escape(word.word),
                escape(word.phonetic ?? ""),
                escape(word.translation ?? ""),
                escape(word.meaning),
                escape(word.meaningTranslation ?? ""),
                escape(word.example ?? ""),
                escape(word.exampleTranslation ?? ""),
                escape(word.imageName ?? ""),
                escape(word.localImagePath ?? ""),
                escape(word.soundPath ?? ""),
                escape(word.soundMeaningPath ?? ""),
                escape(word.soundExamplePath ?? ""),
                word.isFavorite ? "true" : "false",
                "\(word.mistakeCount ?? 0)"
            ].joined(separator: ",")
            result += row + "\n"
        }
        return result
    }
    
    static func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") || text.contains("\r") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }
    
    static func decode(_ content: String) -> [WordEntry] {
        var words: [WordEntry] = []
        let rows = parseCSV(content)
        
        // Header Check
        guard rows.count > 0 else { return [] }
        
        // Map headers to indices
        let headers = rows[0]
        var indexMap: [String: Int] = [:]
        for (i, h) in headers.enumerated() { indexMap[h.trimmingCharacters(in: .whitespacesAndNewlines)] = i }
        
        // Start from row 1
        for i in 1..<rows.count {
            let fields = rows[i]
            // Skip empty rows
            if fields.isEmpty || (fields.count == 1 && fields[0].isEmpty) { continue }
            
            func val(_ key: String) -> String {
                guard let idx = indexMap[key], idx < fields.count else { return "" }
                return fields[idx]
            }
            
            let word = val("word")
            if word.isEmpty { continue }
            
            let entry = WordEntry(
                word: word,
                phonetic: val("phonetic").isEmpty ? nil : val("phonetic"),
                translation: val("translation").isEmpty ? nil : val("translation"),
                meaning: val("meaning"),
                meaningTranslation: val("meaningTranslation").isEmpty ? nil : val("meaningTranslation"),
                example: val("example").isEmpty ? nil : val("example"),
                exampleTranslation: val("exampleTranslation").isEmpty ? nil : val("exampleTranslation"),
                imageName: val("imageName").isEmpty ? nil : val("imageName"),
                localImagePath: val("localImagePath").isEmpty ? nil : val("localImagePath"),
                soundPath: val("soundPath").isEmpty ? nil : val("soundPath"),
                soundMeaningPath: val("soundMeaningPath").isEmpty ? nil : val("soundMeaningPath"),
                soundExamplePath: val("soundExamplePath").isEmpty ? nil : val("soundExamplePath"),
                isFavorite: val("isFavorite") == "true",
                mistakeCount: Int(val("mistakeCount")) ?? 0
            )
            words.append(entry)
        }
        return words
    }
    
    static func parseCSV(_ content: String) -> [[String]] {
        var result: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        
        let scalars = Array(content.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let scalar = scalars[i]
            let char = Character(scalar)
            
            if inQuotes {
                if char == "\"" {
                    if i + 1 < scalars.count && Character(scalars[i+1]) == "\"" {
                        currentField.append("\"")
                        i += 1 // Skip next quote
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if scalar.value == 10 || scalar.value == 13 {
                    // Handle CRLF, LF, or CR
                    if scalar.value == 13 && i + 1 < scalars.count && scalars[i+1].value == 10 {
                         i += 1
                    }
                    currentRow.append(currentField)
                    result.append(currentRow)
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(char)
                }
            }
            i += 1
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            result.append(currentRow)
        }
        
        return result
    }
}
