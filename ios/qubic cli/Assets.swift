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
