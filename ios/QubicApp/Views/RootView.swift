import SwiftUI

struct RootView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var catalog: Catalog
    @EnvironmentObject var history: History
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { CategoriesView() }
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }
                .tag(0)

            NavigationStack { FavoritesView() }
                .tabItem { Label("Favorites", systemImage: "star") }
                .tag(1)

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock") }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(3)
        }
    }
}
