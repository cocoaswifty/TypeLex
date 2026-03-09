import Foundation
import Security

enum KeychainError: LocalizedError {
    case unexpectedStatus(operation: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let operation, let status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown keychain error"
            return "\(operation) failed (\(status)): \(systemMessage)"
        }
    }
}

final class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.typelex.apikey"
    
    // Default keys
    static let geminiKey = "gemini"
    static let stabilityKey = "stability"
    
    func save(_ secret: String, for key: String = KeychainHelper.geminiKey) throws {
        let data = Data(secret.utf8)
        let deleteQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ] as [CFString : Any]

        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(operation: "Delete existing item", status: deleteStatus)
        }

        let addQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as [CFString : Any]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(operation: "Save item", status: addStatus)
        }
    }
    
    func read(for key: String = KeychainHelper.geminiKey) throws -> String? {
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
            throw KeychainError.unexpectedStatus(operation: "Read item", status: errSecInternalError)
        }

        if status == errSecItemNotFound {
            return nil
        }

        throw KeychainError.unexpectedStatus(operation: "Read item", status: status)
    }
    
    func delete(for key: String = KeychainHelper.geminiKey) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ] as [CFString : Any]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(operation: "Delete item", status: status)
        }
    }
}
