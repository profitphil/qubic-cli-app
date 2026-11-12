import Foundation
import Combine
import Security

struct SeedEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String
}

@MainActor
final class Settings: ObservableObject {
    static let maxSeeds = 5

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published var nodeIP: String {
        didSet { UserDefaults.standard.set(nodeIP, forKey: "nodeIP") }
    }
    @Published var nodePort: String {
        didSet { UserDefaults.standard.set(nodePort, forKey: "nodePort") }
    }

    @Published var seeds: [SeedEntry] {
        didSet { persistSeedList() }
    }
    @Published var activeSeedId: UUID? {
        didSet {
            UserDefaults.standard.set(activeSeedId?.uuidString, forKey: "activeSeedId")
        }
    }

    init() {
        baseURL  = UserDefaults.standard.string(forKey: "baseURL")  ?? ""
        nodeIP   = UserDefaults.standard.string(forKey: "nodeIP")   ?? ""
        nodePort = UserDefaults.standard.string(forKey: "nodePort") ?? "21841"

        // Decode seed list (labels only — values live in Keychain).
        if let data = UserDefaults.standard.data(forKey: "seeds"),
           let list = try? JSONDecoder().decode([SeedEntry].self, from: data) {
            seeds = list
        } else {
            seeds = []
        }
        if let s = UserDefaults.standard.string(forKey: "activeSeedId"),
           let uuid = UUID(uuidString: s) {
            activeSeedId = uuid
        } else {
            activeSeedId = nil
        }

        migrateLegacySeedIfNeeded()
    }

    // --- legacy single-seed migration --------------------------------------

    private func migrateLegacySeedIfNeeded() {
        // If user has a stored single seed under the old key and no entries yet,
        // promote it to a labeled entry and make it active.
        guard seeds.isEmpty, let legacy = Keychain.get("qubic.seed"), !legacy.isEmpty else { return }
        let entry = SeedEntry(id: UUID(), label: "Default")
        seeds = [entry]
        Keychain.set(keychainKey(for: entry.id), legacy)
        activeSeedId = entry.id
        Keychain.delete("qubic.seed")
    }

    // --- keychain for secrets (token + seeds) -------------------------------

    var token: String {
        get { Keychain.get("api.token") ?? "" }
        set { Keychain.set("api.token", newValue); objectWillChange.send() }
    }

    /// Convenience: the active seed's value (or "" if none).
    var seed: String {
        guard let id = activeSeedId, seeds.contains(where: { $0.id == id }) else { return "" }
        return Keychain.get(keychainKey(for: id)) ?? ""
    }

    func seedValue(_ id: UUID) -> String {
        Keychain.get(keychainKey(for: id)) ?? ""
    }

    func setSeedValue(_ id: UUID, _ value: String) {
        Keychain.set(keychainKey(for: id), value)
        objectWillChange.send()
    }

    @discardableResult
    func addSeed(label: String, value: String) -> SeedEntry? {
        guard seeds.count < Self.maxSeeds else { return nil }
        let entry = SeedEntry(id: UUID(), label: label)
        seeds.append(entry)
        Keychain.set(keychainKey(for: entry.id), value)
        if activeSeedId == nil { activeSeedId = entry.id }
        return entry
    }

    func updateLabel(_ id: UUID, label: String) {
        guard let i = seeds.firstIndex(where: { $0.id == id }) else { return }
        seeds[i].label = label
    }

    func deleteSeed(_ id: UUID) {
        Keychain.delete(keychainKey(for: id))
        seeds.removeAll { $0.id == id }
        if activeSeedId == id {
            activeSeedId = seeds.first?.id
        }
    }

    func setActive(_ id: UUID) {
        activeSeedId = id
    }

    private func persistSeedList() {
        if let data = try? JSONEncoder().encode(seeds) {
            UserDefaults.standard.set(data, forKey: "seeds")
        }
    }

    private func keychainKey(for id: UUID) -> String {
        "qubic.seed." + id.uuidString
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

    static func delete(_ key: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
