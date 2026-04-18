import Foundation
import Combine
import Security

@MainActor
final class Settings: ObservableObject {
    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published var nodeIP: String {
        didSet { UserDefaults.standard.set(nodeIP, forKey: "nodeIP") }
    }
    @Published var nodePort: String {
        didSet { UserDefaults.standard.set(nodePort, forKey: "nodePort") }
    }

    init() {
        baseURL  = UserDefaults.standard.string(forKey: "baseURL")  ?? ""
        nodeIP   = UserDefaults.standard.string(forKey: "nodeIP")   ?? ""
        nodePort = UserDefaults.standard.string(forKey: "nodePort") ?? "21841"
    }

    // --- keychain for secrets (token + seed) --------------------------------
    var token: String {
        get { Keychain.get("api.token") ?? "" }
        set { Keychain.set("api.token", newValue); objectWillChange.send() }
    }

    var seed: String {
        get { Keychain.get("qubic.seed") ?? "" }
        set { Keychain.set("qubic.seed", newValue); objectWillChange.send() }
    }
}

enum Keychain {
    static func set(_ key: String, _ value: String) {
        let data = Data(value.utf8)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}
