import SwiftUI

struct CommandListView: View {
    let category: CommandCategory
    @EnvironmentObject var catalog: Catalog

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: category.icon)
                            .foregroundStyle(Theme.accent)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.text)
                        Text("\(catalog.commands(in: category.name).count) commands")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                LazyVStack(spacing: 10) {
                    ForEach(catalog.commands(in: category.name)) { cmd in
                        NavigationLink(value: cmd) { CommandCard(command: cmd) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Color.clear.frame(height: 24)
            }
        }
        .qubicBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FavoritesView: View {
    @EnvironmentObject var catalog: Catalog
    @EnvironmentObject var history: History

    var body: some View {
        let favs = catalog.commands.filter { history.isFavorite($0.flag) }
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.accent)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text("Favorites")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if favs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "star")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Theme.textDim)
                        Text("No favorites yet")
                            .foregroundStyle(Theme.text)
                            .font(.headline)
                        Text("Tap the star on any command to pin it here.")
                            .font(.caption)
                            .foregroundStyle(Theme.textDim)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(favs) { cmd in
                            NavigationLink(value: cmd) { CommandCard(command: cmd) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Color.clear.frame(height: 24)
            }
        }
        .qubicBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Command.self) { CommandDetailView(command: $0) }
    }
}
