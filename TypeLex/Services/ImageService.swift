import Foundation
import AppKit

enum ImageProvider {
    case pollinations
    case stabilityAI
}

class ImageService {
    static let shared = ImageService()
    
    // Stability AI SDXL Endpoint
    private let stabilityEndpoint = "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image"
    
    /// Generates an image based on the context, using Pollinations AI first, falling back to Stability AI if it fails.
    func generateImage(context: String) async throws -> Data? {
        // 1. Try Pollinations AI First (Free & No Key)
        do {
            print("🎨 Attempting generation with Pollinations AI...")
            if let data = try await generateWithPollinations(context: context) {
                return data
            }
        } catch {
            print("⚠️ Pollinations AI failed: \(error). Trying fallback...")
        }
        
        // 2. Fallback to Stability AI if Key exists
        if let stabilityKey = KeychainHelper.shared.read(for: KeychainHelper.stabilityKey), !stabilityKey.isEmpty {
            do {
                print("🎨 Attempting fallback generation with Stability AI...")
                return try await generateWithStability(context: context, apiKey: stabilityKey)
            } catch {
                print("❌ Stability AI fallback also failed: \(error)")
                throw error
            }
        }
        
        return nil
    }
    
    // MARK: - Stability AI Implementation
    
    private struct StabilityResponse: Decodable {
        struct Artifact: Decodable {
            let base64: String
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case base64
                case finishReason = "finish_reason"
            }
        }
        let artifacts: [Artifact]
    }
    
    private func generateWithStability(context: String, apiKey: String) async throws -> Data? {
        guard let url = URL(string: stabilityEndpoint) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = "minimalist flat vector illustration of \(context), Morandi color palette, muted desaturated tones, simple clean shapes, high quality, artistic"
        
        let body: [String: Any] = [
            "text_prompts": [
                ["text": prompt, "weight": 1],
                ["text": "blur, low quality, watermark, text, signature, ugly, deformed", "weight": -1] // Negative prompt
            ],
            "cfg_scale": 7,
            "height": 1024,
            "width": 1024,
            "samples": 1,
            "steps": 30
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.apiError("Stability: No Response")
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw GeminiError.apiError("Stability Error (\(httpResponse.statusCode)): \(errorMsg)")
        }
        
        let result = try JSONDecoder().decode(StabilityResponse.self, from: data)
        guard let base64String = result.artifacts.first?.base64 else { return nil }
        
        return Data(base64Encoded: base64String)
    }
    
    // MARK: - Pollinations AI Implementation
    
    private var lastPollinationTime: Date = .distantPast
    
    private func generateWithPollinations(context: String) async throws -> Data? {
        // Rate limit check: enforce 30-second interval between requests to avoid "Rate Limit Reached"
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastPollinationTime)
        if timeSinceLastRequest < 30 {
            throw GeminiError.apiError("Pollinations AI Throttled: \(String(format: "%.1f", timeSinceLastRequest))s since last request (min 30s)")
        }
        
        lastPollinationTime = now
        
        let prompt = "minimalist flat vector illustration of \(context), Morandi color palette, muted desaturated tones, simple clean shapes"
        let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "word"
        
        let seed = Int.random(in: 0...100000)
        let urlString = "https://image.pollinations.ai/prompt/\(encodedPrompt)?width=800&height=450&nologo=true&seed=\(seed)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw GeminiError.apiError("Pollinations AI Error: \(httpResponse.statusCode)")
        }
        
        // Filter out small responses (error messages, HTML) which are usually < 1KB
        guard data.count > 1024 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown binary data"
            throw GeminiError.apiError("Pollinations AI Data Too Small (\(data.count) bytes): \(errorText)")
        }
        
        // Check for "Rate Limit Reached" error image (known to be 1024x1024 while we request 800x450)
        if let imageRep = NSBitmapImageRep(data: data) {
            if imageRep.pixelsWide == 1024 && imageRep.pixelsHigh == 1024 {
                throw GeminiError.apiError("Pollinations AI Returned Error Image (Rate Limit 1024x1024)")
            }
        }
        
        // Validate that the returned data is actually an image
        guard NSImage(data: data) != nil else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown binary data"
            // Log the error content for debugging (truncated to avoid huge logs)
            let truncatedError = errorText.prefix(200).replacingOccurrences(of: "\n", with: " ")
            throw GeminiError.apiError("Pollinations AI Invalid Image Data: \(truncatedError)")
        }
        
        return data
    }
}
