import Foundation
import Combine

struct QubicAsset: Codable, Identifiable, Hashable {
    var id: String { name + "/" + issuer }
    let name: String        // e.g. "QX", "CFB"
    let issuer: String      // 60-char identity
    let note: String?       // optional description
    let custom: Bool        // true = user-added, false = bundled
}

@MainActor
final class AssetsStore: ObservableObject {
    @Published var assets: [QubicAsset] = []
    private let customKey = "assets.custom"

    init() { reload() }

    func reload() {
        let bundled: [QubicAsset] = decode("assets") ?? []
        let custom = loadCustom()
        // dedupe by (name, issuer); custom wins
        var byID: [String: QubicAsset] = [:]
        for a in bundled { byID[a.id] = QubicAsset(name: a.name, issuer: a.issuer, note: a.note, custom: false) }
        for a in custom  { byID[a.id] = QubicAsset(name: a.name, issuer: a.issuer, note: a.note, custom: true) }
        assets = byID.values.sorted { ($0.name, $0.issuer) < ($1.name, $1.issuer) }
    }

    func add(name: String, issuer: String, note: String?) {
        let trimmed = QubicAsset(name: name.trimmingCharacters(in: .whitespaces),
                                 issuer: issuer.trimmingCharacters(in: .whitespaces),
                                 note: (note?.isEmpty == false) ? note : nil,
                                 custom: true)
        var current = loadCustom().filter { $0.id != trimmed.id }
        current.append(trimmed)
        saveCustom(current)
        reload()
    }

    func remove(_ asset: QubicAsset) {
        guard asset.custom else { return }
        let current = loadCustom().filter { $0.id != asset.id }
        saveCustom(current)
        reload()
    }

    private func loadCustom() -> [QubicAsset] {
        guard let data = UserDefaults.standard.data(forKey: customKey),
              let decoded = try? JSONDecoder().decode([QubicAsset].self, from: data)
        else { return [] }
        return decoded
    }

    private func saveCustom(_ items: [QubicAsset]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
    }

    private func decode<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// Detect asset/issuer arg pairs on a command.
enum AssetArgDetector {
    static func isAssetNameArg(_ argName: String) -> Bool {
        let n = argName.uppercased()
        return n.contains("ASSET_NAME") || n == "ASSET"
    }

    static func isIssuerArg(_ argName: String) -> Bool {
        let n = argName.uppercased()
        return n.contains("ISSUER")
    }

    /// Returns (assetArgName, issuerArgName) if the command has both.
    static func detect(_ args: [CommandArg]) -> (String, String)? {
        let asset = args.first(where: { isAssetNameArg($0.name) })?.name
        let issuer = args.first(where: { isIssuerArg($0.name) })?.name
        if let a = asset, let i = issuer { return (a, i) }
        return nil
    }
}



/// Qubic identity (60 chars A–Z) → 32-byte public key as 64-char lowercase hex.
/// Needed for qubic-cli args typed `hex` such as ISSUER_IN_HEX.
enum QubicIdentity {
    static func isIdentity(_ s: String) -> Bool {
        s.count == 60 && s.utf8.allSatisfy { $0 >= 65 && $0 <= 90 }
    }

    static func publicKeyHex(_ identity: String) -> String? {
        guard isIdentity(identity) else { return nil }
        let chars = Array(identity.utf8)
        var out = ""
        for i in 0..<4 {
            var v: UInt64 = 0
            for j in stride(from: 13, through: 0, by: -1) {
                v = v &* 26 &+ UInt64(chars[i * 14 + j] - 65)
            }
            for b in 0..<8 { out += String(format: "%02x", UInt8((v >> UInt64(8 * b)) & 0xff)) }
        }
        return out
    }

    /// For `hex` args: if the user (or the asset picker) supplied a 60-char identity, convert it.
    static func normalizeHexArg(_ value: String) -> String {
        publicKeyHex(value) ?? value
    }
}
