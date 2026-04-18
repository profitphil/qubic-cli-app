import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var catalog: Catalog
    @State private var search = ""

    var body: some View {
        List {
            if !search.isEmpty {
                ForEach(catalog.search(search)) { cmd in
                    NavigationLink(value: cmd) { CommandRow(command: cmd) }
                }
            } else {
                ForEach(catalog.categories.sorted(by: { $0.order < $1.order })) { cat in
                    NavigationLink(value: cat) {
                        Label(cat.name, systemImage: cat.icon)
                            .badge(catalog.commands(in: cat.name).count)
                    }
                }
            }
        }
        .navigationTitle("Qubic")
        .searchable(text: $search, prompt: "Search commands")
        .navigationDestination(for: CommandCategory.self) { cat in
            CommandListView(category: cat)
        }
        .navigationDestination(for: Command.self) { cmd in
            CommandDetailView(command: cmd)
        }
    }
}

struct CommandRow: View {
    @EnvironmentObject var history: History
    let command: Command
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: command.readOnly ? "eye" : (command.needsSeed ? "key.fill" : "bolt"))
                .foregroundStyle(command.readOnly ? .blue : (command.needsSeed ? .orange : .purple))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(command.flag).font(.system(.body, design: .monospaced))
                    if history.isFavorite(command.flag) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                    }
                }
                Text(command.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
