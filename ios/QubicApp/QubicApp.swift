import SwiftUI

@main
struct QubicApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var catalog = Catalog()
    @StateObject private var history = History()
    @StateObject private var assetsStore = AssetsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(history)
                .environmentObject(assetsStore)
        }
    }
}
