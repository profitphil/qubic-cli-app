import Foundation
import Combine

struct HistoryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let flag: String
    let args: [String]      // redacted — no seeds
    let exitCode: Int
    let stdoutHead: String  // first 2KB
}

@MainActor
final class History: ObservableObject {
    @Published var entries: [HistoryEntry] = []
    @Published var favorites: Set<String> = []
    private let entriesKey = "history.entries"
    private let favoritesKey = "history.favorites"
    private let maxEntries = 100

    init() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = decoded
        }
        if let favs = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favorites = Set(favs)
        }
    }

    func record(flag: String, args: [String], response: ExecResponse) {
        let redacted = redact(args)
        let head = String(response.stdout.prefix(2048))
        let entry = HistoryEntry(id: UUID(), date: Date(),
                                 flag: flag, args: redacted,
                                 exitCode: response.exit_code,
                                 stdoutHead: head)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        save()
    }

    func toggleFavorite(_ flag: String) {
        if favorites.contains(flag) { favorites.remove(flag) } else { favorites.insert(flag) }
        UserDefaults.standard.set(Array(favorites), forKey: favoritesKey)
    }

    func isFavorite(_ flag: String) -> Bool { favorites.contains(flag) }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    /// Replace seeds / sensitive values with [redacted].
    private func redact(_ args: [String]) -> [String] {
        var out = args
        for i in 0..<out.count {
            if out[i] == "-seed", i + 1 < out.count {
                out[i + 1] = "[redacted]"
            }
        }
        return out
    }
}
