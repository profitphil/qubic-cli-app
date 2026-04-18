import SwiftUI

struct CommandListView: View {
    let category: CommandCategory
    @EnvironmentObject var catalog: Catalog

    var body: some View {
        List(catalog.commands(in: category.name)) { cmd in
            NavigationLink(value: cmd) { CommandRow(command: cmd) }
        }
        .navigationTitle(category.name)
    }
}

struct FavoritesView: View {
    @EnvironmentObject var catalog: Catalog
    @EnvironmentObject var history: History

    var body: some View {
        let favs = catalog.commands.filter { history.isFavorite($0.flag) }
        Group {
            if favs.isEmpty {
                ContentUnavailableView("No favorites",
                    systemImage: "star",
                    description: Text("Tap the star on any command to pin it here."))
            } else {
                List(favs) { cmd in
                    NavigationLink(value: cmd) { CommandRow(command: cmd) }
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationDestination(for: Command.self) { CommandDetailView(command: $0) }
    }
}
