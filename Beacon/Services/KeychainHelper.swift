import Foundation
import Security

class KeychainHelper {
    
    static let standard = KeychainHelper()
    
    private init() {}
    
    func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary
        
        // Add item
        let status = SecItemAdd(query, nil)
        
        if status == errSecDuplicateItem {
            // Item already exists, update it
            let query = [
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecClass: kSecClassGenericPassword
            ] as CFDictionary
            
            let attributesToUpdate = [kSecValueData: data] as CFDictionary
            
            SecItemUpdate(query, attributesToUpdate)
        }
    }
    
    func read(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        return result as? Data
    }
    
    func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        SecItemDelete(query)
    }
    
    // MARK: - Convenience String wrappers
    
    static func save(key: String, value: String) {
        if let data = value.data(using: .utf8) {
            standard.save(data, service: "uk.baldlygo.beacon", account: key)
        }
    }
    
    static func get(key: String) -> String? {
        if let data = standard.read(service: "uk.baldlygo.beacon", account: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func delete(key: String) {
        standard.delete(service: "uk.baldlygo.beacon", account: key)
    }
}
