import Foundation
import Combine

@MainActor
final class Catalog: ObservableObject {
    @Published var commands: [Command] = []
    @Published var categories: [CommandCategory] = []

    init() { load() }

    func load() {
        commands   = decode("commands")   ?? []
        categories = decode("categories") ?? []
    }

    func commands(in category: String) -> [Command] {
        commands.filter { $0.category == category }
                .sorted { $0.flag < $1.flag }
    }

    func search(_ query: String) -> [Command] {
        let q = query.lowercased()
        return commands.filter {
            $0.flag.lowercased().contains(q) ||
            $0.description.lowercased().contains(q)
        }
    }

    private func decode<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
