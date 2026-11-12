import Foundation
import Combine

struct QubicAddressEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String
    var identity: String      // 60-char A-Z
    var note: String?
}

@MainActor
final class AddressStore: ObservableObject {
    @Published var entries: [QubicAddressEntry] = []
    private let storageKey = "addresses.saved"

    init() { reload() }

    func reload() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([QubicAddressEntry].self, from: data) {
            entries = list.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        } else {
            entries = []
        }
    }

    func add(label: String, identity: String, note: String?) {
        let trimmed = QubicAddressEntry(
            id: UUID(),
            label: label.trimmingCharacters(in: .whitespaces),
            identity: identity.trimmingCharacters(in: .whitespaces).uppercased(),
            note: (note?.isEmpty == false) ? note : nil
        )
        // dedupe by identity — update label if it already exists
        var current = entries.filter { $0.identity != trimmed.identity }
        current.append(trimmed)
        persist(current)
    }

    func update(_ entry: QubicAddressEntry, label: String, note: String?) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entries
        updated[i].label = label.trimmingCharacters(in: .whitespaces)
        updated[i].note = (note?.isEmpty == false) ? note : nil
        persist(updated)
    }

    func remove(_ entry: QubicAddressEntry) {
        let current = entries.filter { $0.id != entry.id }
        persist(current)
    }

    private func persist(_ items: [QubicAddressEntry]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        reload()
    }
}
