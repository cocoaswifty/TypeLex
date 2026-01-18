import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.typelex.apikey"
    
    // Default keys
    static let geminiKey = "gemini"
    static let stabilityKey = "stability"
    
    func save(_ secret: String, for key: String = KeychainHelper.geminiKey) {
        let data = Data(secret.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as [CFString : Any]
        
        // 先刪除舊的
        SecItemDelete(query as CFDictionary)
        // 新增新的
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func read(for key: String = KeychainHelper.geminiKey) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [CFString : Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }
    
    func delete(for key: String = KeychainHelper.geminiKey) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ] as [CFString : Any]
        SecItemDelete(query as CFDictionary)
    }
}