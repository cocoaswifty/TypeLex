import Foundation
import AppKit

enum GeminiError: Error {
    case invalidURL
    case noData
    case parsingError
    case missingApiKey
    case apiError(String)
}

class GeminiService {
    // 使用 gemini-2.5-flash-lite 進行文字生成
    private let textModel = "gemini-2.5-flash-lite" 
    
    private var apiKey: String? {
        return KeychainHelper.shared.read()
    }
    
    func generateWordData(word: String) async throws -> (WordEntry, Data?) {
        guard let _ = apiKey else { throw GeminiError.missingApiKey }
        
        // 1. 生成文字資訊
        let info = try await fetchWordInfo(word: word)
        
        // 2. 生成圖片數據 (Delegate to ImageService)
        let imageData = try await ImageService.shared.generateImage(context: info.example)
        
        // 暫時將 localImagePath 設為 nil，由 Repository 儲存後填入
        let entry = WordEntry(
            word: word,
            phonetic: info.phonetic,
            translation: info.translation,
            meaning: info.meaning,
            meaningTranslation: info.meaningTranslation,
            example: info.example,
            exampleTranslation: info.exampleTranslation,
            imageName: nil,
            localImagePath: nil,
            isFavorite: false,
            mistakeCount: 0
        )
        
        return (entry, imageData)
    }
    
    /// Public wrapper for regenerating text info
    func regenerateWordInfo(word: String) async throws -> (phonetic: String, translation: String?, meaning: String, meaningTranslation: String?, example: String, exampleTranslation: String) {
        let info = try await fetchWordInfo(word: word)
        return (info.phonetic, info.translation, info.meaning, info.meaningTranslation, info.example, info.exampleTranslation)
    }
    
    // MARK: - Text Generation
    
    private struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String
                }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]?
    }
    
    internal struct WordInfoJSON: Decodable {
        let phonetic: String
        let translation: String
        let meaning: String
        let meaningTranslation: String
        let example: String
        let exampleTranslation: String
    }
    
    internal func fetchWordInfo(word: String) async throws -> WordInfoJSON {
        guard let key = apiKey else { throw GeminiError.missingApiKey }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(textModel):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else { throw GeminiError.invalidURL }
        
        let prompt = """
        You are a dictionary assistant. Provide the details for the English word: "\(word)".
        Output ONLY valid JSON with no markdown formatting.

        Requirements:
        1. "phonetic": IPA format.
        2. "translation": Short Traditional Chinese definition.
        3. "meaning": Simple English definition. If verb, start with "To [word] means..."; if noun, start with "[Word] is...". Keep it simple and direct.
        4. "meaningTranslation": Traditional Chinese translation of the meaning. The Chinese translation of the word MUST be enclosed in "「」" (e.g. 「阻止」某人... / 「唾液」是...).
        5. "example": A clear, vivid English sentence demonstrating usage.
        6. "exampleTranslation": Natural Traditional Chinese translation.

        Examples:
        Word: restrain
        {
          "phonetic": "rɪˈstreɪn",
          "translation": "阻止",
          "meaning": "To restrain someone or something means to use physical strength to stop them.",
          "meaningTranslation": "「制止」某人或某物就是用體力阻止他們。",
          "example": "Mike restrained Allen from reaching the door.",
          "exampleTranslation": "麥克阻止艾倫靠近門口。"
        }

        Word: saliva
        {
          "phonetic": "səˈlaɪvə",
          "translation": "唾液",
          "meaning": "Saliva is the watery liquid in people’s mouths that helps in digestion.",
          "meaningTranslation": "「唾液」是口腔中幫助消化的水狀液體。",
          "example": "The baby could not keep the saliva from dripping out of its mouth.",
          "exampleTranslation": "嬰兒無法阻止口水從嘴裡滴下來。"
        }

        Format:
        {
          "phonetic": "IPA phonetic transcription",
          "translation": "Short Traditional Chinese translation",
          "meaning": "Detailed English definition",
          "meaningTranslation": "Traditional Chinese translation of the detailed meaning",
          "example": "A short English example sentence.",
          "exampleTranslation": "Traditional Chinese translation of the example."
        }
        """
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 使用重試機制執行請求
        let data = try await performRequestWithRetry(request: request)
        
        let geminiResp = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResp.candidates?.first?.content.parts.first?.text else {
            throw GeminiError.noData
        }
        
        // 清理 Markdown (如果有 ```json ... ```)
        let cleanText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanText.data(using: .utf8) else { throw GeminiError.parsingError }
        return try JSONDecoder().decode(WordInfoJSON.self, from: jsonData)
    }
    
    // MARK: - Retry Logic
    
    private func performRequestWithRetry(request: URLRequest, maxRetries: Int = 3, initialDelay: UInt64 = 2_000_000_000) async throws -> Data {
        var currentDelay = initialDelay
        
        for attempt in 1...maxRetries {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.apiError("No response")
            }
            
            if httpResponse.statusCode == 200 {
                return data
            }
            
            if httpResponse.statusCode == 429 {
                print("⚠️ Gemini Rate Limit (429). Retrying in \(Double(currentDelay)/1_000_000_000)s... (Attempt \(attempt)/\(maxRetries))")
                
                // 如果是最後一次嘗試，則拋出錯誤
                if attempt == maxRetries {
                    throw GeminiError.apiError("AI 額度已達上限，重試 \(maxRetries) 次後仍失敗。請稍後再試。")
                }
                
                // 等待
                try? await Task.sleep(nanoseconds: currentDelay)
                
                // 指數退避: 2s -> 4s -> 8s
                currentDelay *= 2
                continue
            }
            
            // 其他錯誤直接拋出
            throw GeminiError.apiError("Text API Error: \(String(data: data, encoding: .utf8) ?? "Unknown")")
        }
        
        throw GeminiError.apiError("Unknown Error")
    }
    
    // MARK: - Image Generation Helper
    
    /// Public wrapper for regenerating image
    func regenerateImage(for entry: WordEntry) async throws -> Data? {
        let context = entry.example ?? entry.word
        return try await ImageService.shared.generateImage(context: context)
    }
}